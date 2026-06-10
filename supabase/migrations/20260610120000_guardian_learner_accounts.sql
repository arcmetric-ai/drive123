alter table public.learner_profiles
  add column if not exists account_type text not null default 'learner',
  add column if not exists ward_first_name text,
  add column if not exists ward_last_name text,
  add column if not exists ward_age integer,
  add column if not exists ward_gender text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'learner_profiles_account_type_check'
      and conrelid = 'public.learner_profiles'::regclass
  ) then
    alter table public.learner_profiles
      add constraint learner_profiles_account_type_check
      check (account_type in ('learner', 'guardian'));
  end if;
end $$;

create index if not exists learner_profiles_account_type_idx
  on public.learner_profiles (account_type);
