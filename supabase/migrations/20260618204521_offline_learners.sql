create extension if not exists pgcrypto;

create or replace function public.current_user_is_instructor()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles profile
    where profile.id = auth.uid()
      and profile.role::text = 'instructor'
  );
$$;

grant execute on function public.current_user_is_instructor() to authenticated;

create table if not exists public.external_learners (
  id uuid primary key default gen_random_uuid(),
  instructor_id uuid not null references public.profiles(id) on delete cascade,
  full_name text not null check (char_length(trim(full_name)) > 0),
  phone text,
  guardian_or_contact_name text,
  pickup_address text,
  notes text,
  weekly_availability jsonb not null default '{}'::jsonb,
  learning_focus text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists external_learners_instructor_active_idx
  on public.external_learners (instructor_id, is_active, created_at desc);

alter table public.external_learners enable row level security;

drop policy if exists "instructors can read own external learners"
  on public.external_learners;
create policy "instructors can read own external learners"
on public.external_learners
for select
to authenticated
using (
  instructor_id = auth.uid()
  and public.current_user_is_instructor()
);

drop policy if exists "instructors can create own external learners"
  on public.external_learners;
create policy "instructors can create own external learners"
on public.external_learners
for insert
to authenticated
with check (
  instructor_id = auth.uid()
  and public.current_user_is_instructor()
);

drop policy if exists "instructors can update own external learners"
  on public.external_learners;
create policy "instructors can update own external learners"
on public.external_learners
for update
to authenticated
using (
  instructor_id = auth.uid()
  and public.current_user_is_instructor()
)
with check (
  instructor_id = auth.uid()
  and public.current_user_is_instructor()
);

drop policy if exists "instructors can delete own external learners"
  on public.external_learners;
create policy "instructors can delete own external learners"
on public.external_learners
for delete
to authenticated
using (
  instructor_id = auth.uid()
  and public.current_user_is_instructor()
);

alter table public.lessons
  add column if not exists external_learner_id uuid
    references public.external_learners(id) on delete set null;

alter table public.lessons
  alter column learner_id drop not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'lessons_exactly_one_learner_source'
      and conrelid = 'public.lessons'::regclass
  ) then
    alter table public.lessons
      add constraint lessons_exactly_one_learner_source
      check (
        (learner_id is not null and external_learner_id is null)
        or
        (learner_id is null and external_learner_id is not null)
      );
  end if;
end $$;

create index if not exists lessons_external_learner_idx
  on public.lessons (external_learner_id);

alter table public.lessons enable row level security;

drop policy if exists "Lesson participants can read lessons"
  on public.lessons;
drop policy if exists "Lesson participants can create lessons"
  on public.lessons;
drop policy if exists "Instructors can update their lessons"
  on public.lessons;
drop policy if exists "Learners can cancel own lessons"
  on public.lessons;
drop policy if exists "Instructors can delete scheduled lessons"
  on public.lessons;

create policy "Lesson participants can read lessons"
on public.lessons
for select
to authenticated
using (
  auth.uid() = learner_id
  or auth.uid() = instructor_id
  or exists (
    select 1
    from public.external_learners external
    where external.id = lessons.external_learner_id
      and external.instructor_id = auth.uid()
      and public.current_user_is_instructor()
  )
);

create policy "Lesson participants can create lessons"
on public.lessons
for insert
to authenticated
with check (
  (
    learner_id is not null
    and auth.uid() = learner_id
  )
  or
  (
    auth.uid() = instructor_id
    and (
      learner_id is not null
      or exists (
        select 1
        from public.external_learners external
        where external.id = lessons.external_learner_id
          and external.instructor_id = auth.uid()
          and public.current_user_is_instructor()
      )
    )
  )
);

create policy "Instructors can update their lessons"
on public.lessons
for update
to authenticated
using (auth.uid() = instructor_id)
with check (auth.uid() = instructor_id);

create policy "Learners can cancel own lessons"
on public.lessons
for update
to authenticated
using (auth.uid() = learner_id)
with check (
  auth.uid() = learner_id
  and status = 'cancelled'
  and started_at is null
  and completed_by is null
  and ended_at is null
);

create policy "Instructors can delete scheduled lessons"
on public.lessons
for delete
to authenticated
using (auth.uid() = instructor_id and status = 'scheduled');

grant select, insert, update, delete on public.external_learners to authenticated;
grant select, insert, update, delete on public.lessons to authenticated;
