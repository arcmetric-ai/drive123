create or replace function private.prevent_profile_role_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE'
    and new.role is distinct from old.role
    and (
      old.role is not null
      or new.role = 'instructor'::public.user_role
    ) then
    raise exception 'Account role cannot be changed after signup';
  end if;

  return new;
end;
$$;

revoke all on function private.prevent_profile_role_mutation()
from public, anon, authenticated;

create or replace function private.prevent_instructor_profile_for_non_instructor()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  profile_role public.user_role;
begin
  select profile.role
    into profile_role
  from public.profiles profile
  where profile.id = new.profile_id;

  if profile_role is distinct from 'instructor'::public.user_role then
    raise exception 'Instructor profile requires an instructor account';
  end if;

  return new;
end;
$$;

revoke all on function private.prevent_instructor_profile_for_non_instructor()
from public, anon, authenticated;

drop trigger if exists prevent_instructor_profile_for_non_instructor
  on public.instructor_profiles;

create trigger prevent_instructor_profile_for_non_instructor
  before insert or update of profile_id on public.instructor_profiles
  for each row
  execute function private.prevent_instructor_profile_for_non_instructor();

drop policy if exists "Instructor owns instructor_profile"
  on public.instructor_profiles;

create policy "Instructor owns instructor_profile"
  on public.instructor_profiles
  for all
  to authenticated
  using (
    (select auth.uid()) = profile_id
    and exists (
      select 1
      from public.profiles profile
      where profile.id = instructor_profiles.profile_id
        and profile.role = 'instructor'::public.user_role
    )
  )
  with check (
    (select auth.uid()) = profile_id
    and exists (
      select 1
      from public.profiles profile
      where profile.id = instructor_profiles.profile_id
        and profile.role = 'instructor'::public.user_role
    )
  );

drop policy if exists "Update own profile"
  on public.profiles;

create policy "Update own profile"
  on public.profiles
  for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);
