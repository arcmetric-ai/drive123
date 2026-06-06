alter table public.instructor_profiles
  add column if not exists instructor_license_path text,
  add column if not exists insurance_document_path text,
  add column if not exists background_check_path text,
  add column if not exists municipal_license_path text,
  add column if not exists credentials_status text,
  add column if not exists credentials_submitted_at timestamptz,
  add column if not exists credentials_review_started_at timestamptz,
  add column if not exists credentials_approved_at timestamptz;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'instructor_profiles_credentials_status_check'
  ) then
    alter table public.instructor_profiles
      add constraint instructor_profiles_credentials_status_check
      check (
        credentials_status is null
        or credentials_status in ('not_started', 'pending', 'approved', 'rejected')
      );
  end if;
end $$;

create index if not exists instructor_profiles_credentials_status_idx
  on public.instructor_profiles (credentials_status);

insert into storage.buckets (id, name, public)
values ('instructor-credentials', 'instructor-credentials', false)
on conflict (id) do nothing;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'instructor_credentials_insert_own'
  ) then
    create policy instructor_credentials_insert_own
      on storage.objects
      for insert
      to authenticated
      with check (
        bucket_id = 'instructor-credentials'
        and (storage.foldername(name))[1] = auth.uid()::text
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'instructor_credentials_select_own'
  ) then
    create policy instructor_credentials_select_own
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id = 'instructor-credentials'
        and (storage.foldername(name))[1] = auth.uid()::text
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'instructor_credentials_update_own'
  ) then
    create policy instructor_credentials_update_own
      on storage.objects
      for update
      to authenticated
      using (
        bucket_id = 'instructor-credentials'
        and (storage.foldername(name))[1] = auth.uid()::text
      )
      with check (
        bucket_id = 'instructor-credentials'
        and (storage.foldername(name))[1] = auth.uid()::text
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'instructor_credentials_delete_own'
  ) then
    create policy instructor_credentials_delete_own
      on storage.objects
      for delete
      to authenticated
      using (
        bucket_id = 'instructor-credentials'
        and (storage.foldername(name))[1] = auth.uid()::text
      );
  end if;
end $$;
