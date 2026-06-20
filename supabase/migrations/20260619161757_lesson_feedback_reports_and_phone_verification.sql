alter table public.profiles
  add column if not exists phone_verified_at timestamptz;

create table if not exists public.lesson_feedback (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id) on delete cascade,
  reviewee_id uuid not null references public.profiles(id) on delete cascade,
  reviewer_role text not null check (reviewer_role in ('learner', 'instructor')),
  rating smallint not null check (rating between 1 and 5),
  was_on_time boolean,
  was_friendly boolean,
  vehicle_cleanliness smallint check (
    vehicle_cleanliness is null or vehicle_cleanliness between 1 and 5
  ),
  was_no_show boolean not null default false,
  comment text check (comment is null or char_length(comment) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (lesson_id, reviewer_id)
);

create table if not exists public.user_reports (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid references public.lessons(id) on delete set null,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_user_id uuid not null references public.profiles(id) on delete cascade,
  reason text not null check (
    reason in (
      'no_show',
      'unsafe_behaviour',
      'harassment',
      'discrimination',
      'inappropriate_conduct',
      'vehicle_cleanliness',
      'identity_concern',
      'other'
    )
  ),
  comment text check (comment is null or char_length(comment) <= 2000),
  status text not null default 'submitted' check (
    status in ('submitted', 'under_review', 'resolved', 'dismissed')
  ),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid references public.profiles(id) on delete set null
);

create index if not exists lesson_feedback_lesson_idx
  on public.lesson_feedback (lesson_id);
create index if not exists user_reports_reported_user_idx
  on public.user_reports (reported_user_id, created_at desc);

alter table public.lesson_feedback enable row level security;
alter table public.user_reports enable row level security;

grant select, insert, update on public.lesson_feedback to authenticated;
grant select, insert on public.user_reports to authenticated;

drop policy if exists "Lesson participants manage own feedback"
  on public.lesson_feedback;
create policy "Lesson participants manage own feedback"
on public.lesson_feedback
for all
to authenticated
using (
  reviewer_id = auth.uid()
  and exists (
    select 1 from public.lessons lesson
    where lesson.id = lesson_feedback.lesson_id
      and (lesson.status = 'completed' or lesson.scheduled_at < now())
      and (
        (
          lesson.learner_id = auth.uid()
          and lesson.instructor_id = lesson_feedback.reviewee_id
          and lesson_feedback.reviewer_role = 'learner'
        )
        or
        (
          lesson.instructor_id = auth.uid()
          and lesson.learner_id = lesson_feedback.reviewee_id
          and lesson_feedback.reviewer_role = 'instructor'
        )
      )
  )
)
with check (
  reviewer_id = auth.uid()
  and reviewee_id <> auth.uid()
  and exists (
    select 1 from public.lessons lesson
    where lesson.id = lesson_feedback.lesson_id
      and (lesson.status = 'completed' or lesson.scheduled_at < now())
      and (
        (
          lesson.learner_id = auth.uid()
          and lesson.instructor_id = lesson_feedback.reviewee_id
          and lesson_feedback.reviewer_role = 'learner'
        )
        or
        (
          lesson.instructor_id = auth.uid()
          and lesson.learner_id = lesson_feedback.reviewee_id
          and lesson_feedback.reviewer_role = 'instructor'
        )
      )
  )
);

drop policy if exists "Users submit reports about lesson counterparts"
  on public.user_reports;
create policy "Users submit reports about lesson counterparts"
on public.user_reports
for insert
to authenticated
with check (
  reporter_id = auth.uid()
  and reported_user_id <> auth.uid()
  and (
    lesson_id is null
    or exists (
      select 1 from public.lessons lesson
      where lesson.id = user_reports.lesson_id
        and (
          (lesson.learner_id = auth.uid() and lesson.instructor_id = reported_user_id)
          or
          (lesson.instructor_id = auth.uid() and lesson.learner_id = reported_user_id)
        )
    )
  )
);

drop policy if exists "Users read reports they submitted"
  on public.user_reports;
create policy "Users read reports they submitted"
on public.user_reports
for select
to authenticated
using (reporter_id = auth.uid());

create or replace function public.protect_completed_lesson_fields()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.status = 'completed' and (
    new.instructor_id is distinct from old.instructor_id
    or new.learner_id is distinct from old.learner_id
    or new.external_learner_id is distinct from old.external_learner_id
    or new.scheduled_at is distinct from old.scheduled_at
    or new.start_time is distinct from old.start_time
    or new.end_time is distinct from old.end_time
    or new.duration_hours is distinct from old.duration_hours
    or new.status is distinct from old.status
    or new.started_at is distinct from old.started_at
    or new.ended_at is distinct from old.ended_at
    or new.completed_by is distinct from old.completed_by
  ) then
    raise exception 'Completed lessons are immutable except for notes';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_completed_lesson_fields_trigger
  on public.lessons;
create trigger protect_completed_lesson_fields_trigger
before update on public.lessons
for each row execute function public.protect_completed_lesson_fields();
