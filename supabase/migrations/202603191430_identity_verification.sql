alter table public.profiles
  add column if not exists verification_status text,
  add column if not exists verification_submitted_at timestamptz,
  add column if not exists verification_review_started_at timestamptz,
  add column if not exists verification_approved_at timestamptz,
  add column if not exists identity_license_path text,
  add column if not exists identity_selfie_path text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_verification_status_check'
  ) then
    alter table public.profiles
      add constraint profiles_verification_status_check
      check (
        verification_status is null
        or verification_status in ('pending', 'approved', 'rejected')
      );
  end if;
end $$;

create index if not exists profiles_verification_status_idx
  on public.profiles (verification_status);

insert into storage.buckets (id, name, public)
values ('identity-verification', 'identity-verification', false)
on conflict (id) do nothing;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'identity_verification_insert_own'
  ) then
    create policy identity_verification_insert_own
      on storage.objects
      for insert
      to authenticated
      with check (
        bucket_id = 'identity-verification'
        and (storage.foldername(name))[1] = auth.uid()::text
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'identity_verification_select_own'
  ) then
    create policy identity_verification_select_own
      on storage.objects
      for select
      to authenticated
      using (
        bucket_id = 'identity-verification'
        and (storage.foldername(name))[1] = auth.uid()::text
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'identity_verification_update_own'
  ) then
    create policy identity_verification_update_own
      on storage.objects
      for update
      to authenticated
      using (
        bucket_id = 'identity-verification'
        and (storage.foldername(name))[1] = auth.uid()::text
      )
      with check (
        bucket_id = 'identity-verification'
        and (storage.foldername(name))[1] = auth.uid()::text
      );
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'identity_verification_delete_own'
  ) then
    create policy identity_verification_delete_own
      on storage.objects
      for delete
      to authenticated
      using (
        bucket_id = 'identity-verification'
        and (storage.foldername(name))[1] = auth.uid()::text
      );
  end if;
end $$;
