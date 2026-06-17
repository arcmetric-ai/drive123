alter table public.instructor_profiles
  add column if not exists drive_tutor_number text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'instructor_profiles_drive_tutor_number_format_check'
      and conrelid = 'public.instructor_profiles'::regclass
  ) then
    alter table public.instructor_profiles
      add constraint instructor_profiles_drive_tutor_number_format_check
      check (
        drive_tutor_number is null
        or drive_tutor_number ~ '^[A-Z][0-9]-[0-9]{6}$'
      );
  end if;
end $$;

create unique index if not exists instructor_profiles_drive_tutor_number_key
  on public.instructor_profiles (drive_tutor_number)
  where drive_tutor_number is not null;

create index if not exists instructor_profiles_drive_tutor_number_search_idx
  on public.instructor_profiles (lower(drive_tutor_number))
  where drive_tutor_number is not null;
