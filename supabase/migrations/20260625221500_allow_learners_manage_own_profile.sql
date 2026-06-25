do $$
begin
  if to_regclass('public.learner_profiles') is not null then
    execute 'alter table public.learner_profiles enable row level security';

    execute 'grant select, insert, update on public.learner_profiles to authenticated';

    execute 'drop policy if exists "learners can select own learner profile" on public.learner_profiles';
    execute 'drop policy if exists "learners can insert own learner profile" on public.learner_profiles';
    execute 'drop policy if exists "learners can update own learner profile" on public.learner_profiles';

    execute 'create policy "learners can select own learner profile"
      on public.learner_profiles
      for select
      to authenticated
      using (profile_id = auth.uid())';

    execute 'create policy "learners can insert own learner profile"
      on public.learner_profiles
      for insert
      to authenticated
      with check (profile_id = auth.uid())';

    execute 'create policy "learners can update own learner profile"
      on public.learner_profiles
      for update
      to authenticated
      using (profile_id = auth.uid())
      with check (profile_id = auth.uid())';
  end if;
end $$;
