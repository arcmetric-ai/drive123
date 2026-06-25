alter table public.profiles
  drop constraint if exists profiles_role_age_policy_check;

alter table public.profiles
  add constraint profiles_role_age_policy_check
  check (
    role is null
    or (
      role::text = 'instructor'
      and (
        (age is not null and age >= 21 and age <= 100)
        or (
          age is null
          and onboarding_stage = 'role_selected'
          and is_verified is not true
          and verification_status is null
        )
      )
    )
    or (
      role::text = 'learner'
      and (age is null or (age >= 18 and age <= 100))
    )
    or (
      role::text = 'guardian'
      and (age is null or (age >= 18 and age <= 100))
    )
  ) not valid;
