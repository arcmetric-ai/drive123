do $$
begin
  if to_regclass('public.lessons') is not null then
    alter table public.lessons
      add column if not exists started_at timestamptz,
      add column if not exists ended_at timestamptz,
      add column if not exists completed_by uuid references public.profiles(id) on delete set null;

    create index if not exists lessons_started_at_idx
      on public.lessons (started_at);

    create index if not exists lessons_ended_at_idx
      on public.lessons (ended_at);

    alter table public.lessons enable row level security;

    drop policy if exists "Lesson participants manage lessons"
      on public.lessons;
    drop policy if exists "Participants can manage lessons"
      on public.lessons;
    drop policy if exists "Lesson participants can read lessons"
      on public.lessons;
    drop policy if exists "Lesson participants can create lessons"
      on public.lessons;
    drop policy if exists "Instructors can update their lessons"
      on public.lessons;
    drop policy if exists "Learners can cancel own lessons"
      on public.lessons;

    create policy "Lesson participants can read lessons"
      on public.lessons
      for select
      to authenticated
      using (auth.uid() = learner_id or auth.uid() = instructor_id);

    create policy "Lesson participants can create lessons"
      on public.lessons
      for insert
      to authenticated
      with check (auth.uid() = learner_id or auth.uid() = instructor_id);

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
  end if;
end $$;
