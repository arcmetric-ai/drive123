do $$
begin
  if to_regclass('public.learner_skill_progress') is not null then
    alter table public.learner_skill_progress
      add column if not exists status text not null default 'not_started',
      add column if not exists updated_by uuid references public.profiles(id) on delete set null,
      add column if not exists updated_by_role text,
      add column if not exists updated_at timestamptz not null default now();

    update public.learner_skill_progress
    set status = case
      when is_completed is true then 'test_ready'
      else 'not_started'
    end
    where status is null or status = '';

    alter table public.learner_skill_progress
      alter column status set default 'not_started',
      alter column updated_at set default now();

    if not exists (
      select 1
      from pg_constraint
      where conname = 'learner_skill_progress_status_check'
        and conrelid = 'public.learner_skill_progress'::regclass
    ) then
      alter table public.learner_skill_progress
        add constraint learner_skill_progress_status_check
        check (status in ('not_started', 'practicing', 'confident', 'test_ready'));
    end if;

    if not exists (
      select 1
      from pg_constraint
      where conname = 'learner_skill_progress_updated_by_role_check'
        and conrelid = 'public.learner_skill_progress'::regclass
    ) then
      alter table public.learner_skill_progress
        add constraint learner_skill_progress_updated_by_role_check
        check (
          updated_by_role is null
          or updated_by_role in ('learner', 'instructor', 'admin')
        );
    end if;

    alter table public.learner_skill_progress enable row level security;

    grant select, insert, update on public.learner_skill_progress to authenticated;

    drop policy if exists "Learner can insert learner profile"
      on public.learner_skill_progress;
    drop policy if exists "Learner can update learner profile"
      on public.learner_skill_progress;
    drop policy if exists "Learner can read learner profile"
      on public.learner_skill_progress;
    drop policy if exists "Learner can read own skill progress"
      on public.learner_skill_progress;
    drop policy if exists "Instructor can read connected learner progress"
      on public.learner_skill_progress;
    drop policy if exists "Instructor can insert connected learner progress"
      on public.learner_skill_progress;
    drop policy if exists "Instructor can update connected learner progress"
      on public.learner_skill_progress;

    create policy "Learner can read own skill progress"
      on public.learner_skill_progress
      for select
      to authenticated
      using (auth.uid() = profile_id);

    create policy "Instructor can read connected learner progress"
      on public.learner_skill_progress
      for select
      to authenticated
      using (
        exists (
          select 1
          from public.learner_requests lr
          where lr.learner_id = learner_skill_progress.profile_id
            and lr.instructor_id = auth.uid()
            and lr.status in ('accepted', 'active', 'in_progress')
        )
      );

    create policy "Instructor can insert connected learner progress"
      on public.learner_skill_progress
      for insert
      to authenticated
      with check (
        updated_by = auth.uid()
        and updated_by_role = 'instructor'
        and exists (
          select 1
          from public.learner_requests lr
          where lr.learner_id = learner_skill_progress.profile_id
            and lr.instructor_id = auth.uid()
            and lr.status in ('accepted', 'active', 'in_progress')
        )
      );

    create policy "Instructor can update connected learner progress"
      on public.learner_skill_progress
      for update
      to authenticated
      using (
        exists (
          select 1
          from public.learner_requests lr
          where lr.learner_id = learner_skill_progress.profile_id
            and lr.instructor_id = auth.uid()
            and lr.status in ('accepted', 'active', 'in_progress')
        )
      )
      with check (
        updated_by = auth.uid()
        and updated_by_role = 'instructor'
        and exists (
          select 1
          from public.learner_requests lr
          where lr.learner_id = learner_skill_progress.profile_id
            and lr.instructor_id = auth.uid()
            and lr.status in ('accepted', 'active', 'in_progress')
        )
      );
  end if;
end $$;
