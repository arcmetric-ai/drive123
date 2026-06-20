create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- Keep this migration independently deployable. Some existing projects were
-- created before credential expiry columns were introduced.
alter table public.instructor_profiles
  add column if not exists instructor_license_expires_at timestamptz,
  add column if not exists insurance_document_expires_at timestamptz,
  add column if not exists municipal_license_expires_at timestamptz;

create index if not exists instructor_profiles_license_expiry_idx
  on public.instructor_profiles (instructor_license_expires_at);

create index if not exists instructor_profiles_insurance_expiry_idx
  on public.instructor_profiles (insurance_document_expires_at);

create table if not exists public.verification_document_versions (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null,
  uploaded_by uuid not null,
  document_type text not null check (
    document_type in (
      'identity_license',
      'guardian_identity_license',
      'instructor_license',
      'insurance_document',
      'background_check',
      'municipal_license'
    )
  ),
  version_number integer not null check (version_number > 0),
  storage_bucket text not null check (
    storage_bucket in ('identity-verification', 'instructor-credentials')
  ),
  storage_path text not null check (
    length(storage_path) between 10 and 1024
    and storage_path !~ '(^|/)\.\.(/|$)'
  ),
  original_file_name text check (
    original_file_name is null
    or (
      length(original_file_name) between 1 and 255
      and original_file_name !~ '[[:cntrl:]/\\]'
    )
  ),
  mime_type text not null check (
    mime_type in ('application/pdf', 'image/jpeg', 'image/png')
  ),
  size_bytes bigint not null check (size_bytes between 1 and 10485760),
  sha256_hex text check (sha256_hex is null or sha256_hex ~ '^[0-9a-f]{64}$'),
  expires_at timestamptz,
  uploaded_at timestamptz not null default now(),
  source text not null default 'mobile_app' check (
    source in ('mobile_app', 'website', 'admin', 'legacy_backfill')
  ),
  unique (owner_user_id, document_type, version_number),
  unique (storage_bucket, storage_path)
);

comment on table public.verification_document_versions is
  'Append-only evidence ledger. Credential and licence files are never updated or deleted.';

create index if not exists verification_document_versions_owner_type_idx
  on public.verification_document_versions (owner_user_id, document_type, version_number desc);

create table if not exists public.verification_document_review_events (
  id uuid primary key default gen_random_uuid(),
  document_version_id uuid not null references public.verification_document_versions(id) on delete restrict,
  status text not null check (status in ('pending', 'approved', 'rejected', 'expired', 'superseded')),
  reviewed_by uuid,
  notes text check (notes is null or length(notes) <= 4000),
  rejection_reason text check (rejection_reason is null or length(rejection_reason) <= 2000),
  created_at timestamptz not null default now()
);

create table if not exists public.verification_document_scan_events (
  id uuid primary key default gen_random_uuid(),
  document_version_id uuid not null references public.verification_document_versions(id) on delete restrict,
  status text not null check (status in ('pending', 'clean', 'infected', 'error')),
  provider text check (provider is null or length(provider) between 1 and 100),
  engine_version text check (engine_version is null or length(engine_version) <= 100),
  threat_name text check (threat_name is null or length(threat_name) <= 255),
  details jsonb not null default '{}'::jsonb check (pg_column_size(details) <= 16384),
  created_at timestamptz not null default now()
);

comment on table public.verification_document_scan_events is
  'Append-only malware scan history. Admin previews require the latest event to be clean.';

comment on table public.verification_document_review_events is
  'Append-only review history for immutable document versions.';

create index if not exists verification_document_review_events_version_idx
  on public.verification_document_review_events (document_version_id, created_at desc);
create index if not exists verification_document_scan_events_version_idx
  on public.verification_document_scan_events (document_version_id, created_at desc);

alter table public.verification_document_versions enable row level security;
alter table public.verification_document_review_events enable row level security;
alter table public.verification_document_scan_events enable row level security;

drop policy if exists "owners read own verification document versions"
  on public.verification_document_versions;
create policy "owners read own verification document versions"
  on public.verification_document_versions
  for select
  to authenticated
  using ((select auth.uid()) = owner_user_id);

drop policy if exists "owners read own verification document reviews"
  on public.verification_document_review_events;
create policy "owners read own verification document reviews"
  on public.verification_document_review_events
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.verification_document_versions document
      where document.id = verification_document_review_events.document_version_id
        and document.owner_user_id = (select auth.uid())
    )
  );

revoke all on public.verification_document_versions from anon, authenticated;
revoke all on public.verification_document_review_events from anon, authenticated;
grant select on public.verification_document_versions to authenticated;
grant select on public.verification_document_review_events to authenticated;
revoke all on public.verification_document_scan_events from public, anon, authenticated;

create or replace function private.prevent_verification_evidence_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Verification evidence is append-only';
end;
$$;

drop trigger if exists prevent_verification_document_version_mutation
  on public.verification_document_versions;
create trigger prevent_verification_document_version_mutation
  before update or delete on public.verification_document_versions
  for each row execute function private.prevent_verification_evidence_mutation();

drop trigger if exists prevent_verification_document_review_mutation
  on public.verification_document_review_events;
create trigger prevent_verification_document_review_mutation
  before update or delete on public.verification_document_review_events
  for each row execute function private.prevent_verification_evidence_mutation();

drop trigger if exists prevent_verification_document_scan_mutation
  on public.verification_document_scan_events;
create trigger prevent_verification_document_scan_mutation
  before update or delete on public.verification_document_scan_events
  for each row execute function private.prevent_verification_evidence_mutation();

create or replace function private.register_verification_document_version(
  p_document_type text,
  p_storage_bucket text,
  p_storage_path text,
  p_original_file_name text,
  p_mime_type text,
  p_size_bytes bigint,
  p_sha256_hex text default null,
  p_expires_at timestamptz default null
)
returns public.verification_document_versions
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_expected_bucket text;
  v_version integer;
  v_document public.verification_document_versions;
  v_object storage.objects;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_document_type not in (
    'identity_license',
    'guardian_identity_license',
    'instructor_license',
    'insurance_document',
    'background_check',
    'municipal_license'
  ) then
    raise exception 'Unsupported document type';
  end if;

  v_expected_bucket := case
    when p_document_type in ('identity_license', 'guardian_identity_license')
      then 'identity-verification'
    else 'instructor-credentials'
  end;

  if p_storage_bucket is distinct from v_expected_bucket then
    raise exception 'Document bucket does not match document type';
  end if;

  if p_storage_path !~ ('^' || v_user_id::text || '/documents/[A-Za-z0-9_.-]+$') then
    raise exception 'Invalid document storage path';
  end if;

  select * into v_object
  from storage.objects
  where bucket_id = p_storage_bucket
    and name = p_storage_path
    and owner_id = v_user_id::text;

  if not found then
    raise exception 'Uploaded storage object was not found for this user';
  end if;

  if coalesce(v_object.metadata ->> 'mimetype', '') is distinct from p_mime_type then
    raise exception 'Storage content type does not match registration';
  end if;

  if coalesce((v_object.metadata ->> 'size')::bigint, 0) is distinct from p_size_bytes then
    raise exception 'Storage object size does not match registration';
  end if;

  if p_mime_type not in ('application/pdf', 'image/jpeg', 'image/png') then
    raise exception 'Unsupported document content type';
  end if;

  if p_size_bytes is null or p_size_bytes < 1 or p_size_bytes > 10485760 then
    raise exception 'Document must be between 1 byte and 10 MB';
  end if;

  if p_original_file_name is not null and (
    length(p_original_file_name) > 255
    or p_original_file_name ~ '[[:cntrl:]/\\]'
  ) then
    raise exception 'Invalid original file name';
  end if;

  if p_document_type in ('instructor_license', 'insurance_document', 'municipal_license')
    and p_expires_at is null then
    raise exception 'Expiry date is required for this document type';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text || ':' || p_document_type, 0));

  select coalesce(max(version_number), 0) + 1
    into v_version
  from public.verification_document_versions
  where owner_user_id = v_user_id
    and document_type = p_document_type;

  insert into public.verification_document_versions (
    owner_user_id,
    uploaded_by,
    document_type,
    version_number,
    storage_bucket,
    storage_path,
    original_file_name,
    mime_type,
    size_bytes,
    sha256_hex,
    expires_at
  ) values (
    v_user_id,
    v_user_id,
    p_document_type,
    v_version,
    p_storage_bucket,
    p_storage_path,
    nullif(trim(p_original_file_name), ''),
    p_mime_type,
    p_size_bytes,
    nullif(lower(trim(p_sha256_hex)), ''),
    p_expires_at
  ) returning * into v_document;

  insert into public.verification_document_review_events (
    document_version_id,
    status
  ) values (v_document.id, 'pending');

  insert into public.verification_document_scan_events (
    document_version_id,
    status,
    provider
  ) values (v_document.id, 'pending', 'unassigned');

  if p_document_type = 'identity_license' then
    update public.profiles
      set identity_license_path = p_storage_path
      where id = v_user_id;
  elsif p_document_type = 'guardian_identity_license' then
    update public.profiles
      set guardian_identity_license_path = p_storage_path
      where id = v_user_id;
  elsif p_document_type = 'instructor_license' then
    update public.instructor_profiles
      set instructor_license_path = p_storage_path,
          instructor_license_expires_at = p_expires_at
      where profile_id = v_user_id;
  elsif p_document_type = 'insurance_document' then
    update public.instructor_profiles
      set insurance_document_path = p_storage_path,
          insurance_document_expires_at = p_expires_at
      where profile_id = v_user_id;
  elsif p_document_type = 'background_check' then
    update public.instructor_profiles
      set background_check_path = p_storage_path
      where profile_id = v_user_id;
  elsif p_document_type = 'municipal_license' then
    update public.instructor_profiles
      set municipal_license_path = p_storage_path,
          municipal_license_expires_at = p_expires_at
      where profile_id = v_user_id;
  end if;

  return v_document;
end;
$$;

create or replace function public.register_verification_document_version(
  p_document_type text,
  p_storage_bucket text,
  p_storage_path text,
  p_original_file_name text,
  p_mime_type text,
  p_size_bytes bigint,
  p_sha256_hex text default null,
  p_expires_at timestamptz default null
)
returns public.verification_document_versions
language sql
security definer
set search_path = ''
as $$
  select private.register_verification_document_version(
    p_document_type,
    p_storage_bucket,
    p_storage_path,
    p_original_file_name,
    p_mime_type,
    p_size_bytes,
    p_sha256_hex,
    p_expires_at
  );
$$;

revoke all on function public.register_verification_document_version(
  text, text, text, text, text, bigint, text, timestamptz
) from public, anon;
grant execute on function public.register_verification_document_version(
  text, text, text, text, text, bigint, text, timestamptz
) to authenticated;

insert into public.verification_document_versions (
  owner_user_id, uploaded_by, document_type, version_number,
  storage_bucket, storage_path, mime_type, size_bytes, expires_at, source
)
select p.id, p.id, source.document_type, 1,
       'identity-verification', source.storage_path,
       case when lower(source.storage_path) like '%.pdf' then 'application/pdf'
            when lower(source.storage_path) like '%.png' then 'image/png'
            else 'image/jpeg' end,
       1, null, 'legacy_backfill'
from public.profiles p
cross join lateral (values
  ('identity_license', p.identity_license_path),
  ('guardian_identity_license', p.guardian_identity_license_path)
) source(document_type, storage_path)
where nullif(trim(source.storage_path), '') is not null
on conflict do nothing;

insert into public.verification_document_versions (
  owner_user_id, uploaded_by, document_type, version_number,
  storage_bucket, storage_path, mime_type, size_bytes, expires_at, source
)
select p.profile_id, p.profile_id, source.document_type, 1,
       'instructor-credentials', source.storage_path,
       case when lower(source.storage_path) like '%.pdf' then 'application/pdf'
            when lower(source.storage_path) like '%.png' then 'image/png'
            else 'image/jpeg' end,
       1, source.expires_at, 'legacy_backfill'
from public.instructor_profiles p
cross join lateral (values
  ('instructor_license', p.instructor_license_path, p.instructor_license_expires_at),
  ('insurance_document', p.insurance_document_path, p.insurance_document_expires_at),
  ('background_check', p.background_check_path, null::timestamptz),
  ('municipal_license', p.municipal_license_path, p.municipal_license_expires_at)
) source(document_type, storage_path, expires_at)
where nullif(trim(source.storage_path), '') is not null
on conflict do nothing;

insert into public.verification_document_review_events (document_version_id, status)
select document.id, 'pending'
from public.verification_document_versions document
where not exists (
  select 1 from public.verification_document_review_events review
  where review.document_version_id = document.id
);

insert into public.verification_document_scan_events (document_version_id, status, provider)
select document.id, 'pending', 'legacy_backfill'
from public.verification_document_versions document
where not exists (
  select 1 from public.verification_document_scan_events scan
  where scan.document_version_id = document.id
);

create or replace function public.record_verification_document_scan(
  p_document_version_id uuid,
  p_status text,
  p_provider text,
  p_engine_version text default null,
  p_threat_name text default null,
  p_details jsonb default '{}'::jsonb
)
returns public.verification_document_scan_events
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event public.verification_document_scan_events;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;
  if p_status not in ('clean', 'infected', 'error') then
    raise exception 'Invalid terminal scan status';
  end if;
  if not exists (
    select 1 from public.verification_document_versions
    where id = p_document_version_id
  ) then
    raise exception 'Document version not found';
  end if;

  insert into public.verification_document_scan_events (
    document_version_id, status, provider, engine_version, threat_name, details
  ) values (
    p_document_version_id,
    p_status,
    left(nullif(trim(p_provider), ''), 100),
    left(nullif(trim(p_engine_version), ''), 100),
    left(nullif(trim(p_threat_name), ''), 255),
    coalesce(p_details, '{}'::jsonb)
  ) returning * into v_event;
  return v_event;
end;
$$;

revoke all on function public.record_verification_document_scan(
  uuid, text, text, text, text, jsonb
) from public, anon, authenticated;
grant execute on function public.record_verification_document_scan(
  uuid, text, text, text, text, jsonb
) to service_role;

drop policy if exists identity_verification_update_own on storage.objects;
drop policy if exists identity_verification_delete_own on storage.objects;
drop policy if exists instructor_credentials_update_own on storage.objects;
drop policy if exists instructor_credentials_delete_own on storage.objects;
drop policy if exists identity_verification_update_mutable_media_only on storage.objects;
drop policy if exists identity_verification_delete_mutable_media_only on storage.objects;

create policy identity_verification_update_mutable_media_only
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'identity-verification'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and (storage.foldername(name))[2] = 'mutable'
  )
  with check (
    bucket_id = 'identity-verification'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and (storage.foldername(name))[2] = 'mutable'
  );

create policy identity_verification_delete_mutable_media_only
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'identity-verification'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and (storage.foldername(name))[2] = 'mutable'
  );

update storage.buckets
set file_size_limit = 10485760,
    allowed_mime_types = array['application/pdf', 'image/jpeg', 'image/png']
where id in ('identity-verification', 'instructor-credentials');

create table if not exists public.admin_account_actions (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid not null,
  target_user_id uuid not null,
  action text not null check (action in ('password_recovery_sent', 'sessions_revoked')),
  request_id uuid not null default gen_random_uuid(),
  created_at timestamptz not null default now()
);

alter table public.admin_account_actions enable row level security;
revoke all on public.admin_account_actions from public, anon, authenticated;
create index if not exists admin_account_actions_target_idx
  on public.admin_account_actions (target_user_id, created_at desc);

create or replace function private.revoke_user_sessions(p_target_user_id uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_deleted integer;
begin
  delete from auth.sessions where user_id = p_target_user_id;
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

create or replace function public.admin_revoke_user_sessions(p_target_user_id uuid)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;
  return private.revoke_user_sessions(p_target_user_id);
end;
$$;

revoke all on function public.admin_revoke_user_sessions(uuid) from public, anon, authenticated;
grant execute on function public.admin_revoke_user_sessions(uuid) to service_role;
grant execute on function private.revoke_user_sessions(uuid) to service_role;

create or replace function public.is_auth_session_active(p_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.role() = 'service_role'
    and exists (
      select 1 from auth.sessions session
      where session.id = p_session_id
    );
$$;

revoke all on function public.is_auth_session_active(uuid)
  from public, anon, authenticated;
grant execute on function public.is_auth_session_active(uuid) to service_role;

-- Repair a production-only legacy helper whose unqualified parameter names
-- currently make every call fail and whose SECURITY DEFINER boundary must not
-- allow one authenticated user to mutate another user's profile.
create or replace function public.update_profile_after_signup(
  user_id uuid,
  first_name text,
  last_name text,
  role public.user_role,
  phone text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  if auth.uid() <> $1 and auth.role() <> 'service_role' then
    raise exception 'Cannot update another user profile';
  end if;
  if char_length(trim(coalesce($2, ''))) not between 1 and 100
    or char_length(trim(coalesce($3, ''))) not between 1 and 100
    or $2 ~ '[[:cntrl:]]'
    or $3 ~ '[[:cntrl:]]' then
    raise exception 'Invalid profile name';
  end if;
  if $5 is not null and (char_length($5) > 32 or $5 ~ '[[:cntrl:]]') then
    raise exception 'Invalid phone number';
  end if;

  update public.profiles profile
  set first_name = trim($2),
      last_name = trim($3),
      role = $4,
      phone = nullif(trim($5), ''),
      updated_at = now()
  where profile.id = $1;
end;
$$;

revoke all on function public.update_profile_after_signup(
  uuid, text, text, public.user_role, text
) from public, anon;
grant execute on function public.update_profile_after_signup(
  uuid, text, text, public.user_role, text
) to authenticated, service_role;

-- Database-side size and shape limits are the final guard against clients that
-- bypass Flutter or the website. Text remains Unicode and is not destructively
-- rewritten; only control bytes and abusive payload sizes are rejected.
alter table public.external_learners
  drop constraint if exists external_learners_full_name_safe_check,
  drop constraint if exists external_learners_phone_safe_check,
  drop constraint if exists external_learners_contact_safe_check,
  drop constraint if exists external_learners_address_safe_check,
  drop constraint if exists external_learners_notes_safe_check,
  drop constraint if exists external_learners_availability_size_check;
alter table public.external_learners
  add constraint external_learners_full_name_safe_check
    check (char_length(trim(full_name)) between 1 and 160 and full_name !~ '[[:cntrl:]]') not valid,
  add constraint external_learners_phone_safe_check
    check (phone is null or (char_length(phone) <= 32 and phone !~ '[[:cntrl:]]')) not valid,
  add constraint external_learners_contact_safe_check
    check (guardian_or_contact_name is null or (char_length(guardian_or_contact_name) <= 160 and guardian_or_contact_name !~ '[[:cntrl:]]')) not valid,
  add constraint external_learners_address_safe_check
    check (pickup_address is null or (char_length(pickup_address) <= 500 and pickup_address !~ '[[:cntrl:]]')) not valid,
  add constraint external_learners_notes_safe_check
    check (notes is null or char_length(notes) <= 4000) not valid,
  add constraint external_learners_availability_size_check
    check (pg_column_size(weekly_availability) <= 32768) not valid;

do $$
declare
  item record;
begin
  for item in
    select * from (values
      ('profiles', 'first_name', 100),
      ('profiles', 'last_name', 100),
      ('profiles', 'phone', 32),
      ('profiles', 'city', 120),
      ('profiles', 'gender', 50),
      ('instructor_profiles', 'bio', 4000),
      ('instructor_profiles', 'instructor_license_number', 100),
      ('learner_profiles', 'g1_license_number', 100),
      ('learner_profiles', 'ward_first_name', 100),
      ('learner_profiles', 'ward_last_name', 100),
      ('lessons', 'focus', 160),
      ('lessons', 'pickup_location', 500),
      ('lessons', 'notes', 4000),
      ('learner_requests', 'message', 2000)
    ) as fields(table_name, column_name, max_length)
  loop
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = item.table_name
        and column_name = item.column_name
        and data_type in ('text', 'character varying', 'character')
    ) then
      execute format(
        'alter table public.%I drop constraint if exists %I',
        item.table_name,
        item.table_name || '_' || item.column_name || '_safe_check'
      );
      execute format(
        'alter table public.%I add constraint %I check (%I is null or (char_length(%I) <= %s and %I !~ E''[\\x00-\\x08\\x0B\\x0C\\x0E-\\x1F\\x7F]'')) not valid',
        item.table_name,
        item.table_name || '_' || item.column_name || '_safe_check',
        item.column_name,
        item.column_name,
        item.max_length,
        item.column_name
      );
    end if;
  end loop;
end $$;
