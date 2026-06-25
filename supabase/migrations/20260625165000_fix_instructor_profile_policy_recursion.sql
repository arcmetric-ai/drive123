begin;

drop policy if exists "Instructor owns instructor_profile"
  on public.instructor_profiles;

create policy "Instructor owns instructor_profile"
  on public.instructor_profiles
  for all
  to authenticated
  using ((select auth.uid()) = profile_id)
  with check ((select auth.uid()) = profile_id);

comment on policy "Instructor owns instructor_profile"
  on public.instructor_profiles is
  'Keeps owner access non-recursive. Instructor-only inserts/updates are enforced by prevent_instructor_profile_for_non_instructor.';

commit;
