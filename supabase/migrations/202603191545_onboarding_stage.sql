alter table public.profiles
  add column if not exists onboarding_stage text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_onboarding_stage_check'
  ) then
    alter table public.profiles
      add constraint profiles_onboarding_stage_check
      check (
        onboarding_stage is null
        or onboarding_stage in (
          'role_selected',
          'verification_pending',
          'questionnaire_complete'
        )
      );
  end if;
end $$;

create index if not exists profiles_onboarding_stage_idx
  on public.profiles (onboarding_stage);
