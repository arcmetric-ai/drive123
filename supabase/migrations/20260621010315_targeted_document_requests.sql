create table if not exists public.verification_document_requests (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  requested_by uuid not null references auth.users(id) on delete restrict,
  review_type text not null
    check (review_type in ('identity_verification', 'instructor_credentials')),
  document_type text not null
    check (document_type in (
      'identity_license',
      'identity_selfie',
      'guardian_identity_license',
      'guardian_identity_selfie',
      'instructor_license',
      'insurance_document',
      'background_check',
      'municipal_license'
    )),
  status text not null default 'requested'
    check (status in ('requested', 'uploaded', 'reviewed', 'cancelled')),
  admin_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint verification_document_requests_message_length
    check (admin_message is null or char_length(admin_message) <= 1000)
);

create index if not exists verification_document_requests_profile_idx
  on public.verification_document_requests (profile_id, status, created_at desc);

create unique index if not exists verification_document_requests_open_unique_idx
  on public.verification_document_requests (profile_id, document_type)
  where status = 'requested';

alter table public.verification_document_requests enable row level security;

drop policy if exists "users can read own document requests"
  on public.verification_document_requests;
create policy "users can read own document requests"
on public.verification_document_requests
for select
to authenticated
using (profile_id = auth.uid());

revoke all on public.verification_document_requests from public, anon;
grant select on public.verification_document_requests to authenticated;

comment on table public.verification_document_requests is
  'Append-only admin requests for a specific verification or credential document.';

create or replace function private.mark_document_request_uploaded()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.verification_document_requests
  set status = 'uploaded',
      completed_at = now(),
      updated_at = now()
  where profile_id = new.owner_user_id
    and document_type = new.document_type
    and status = 'requested';
  return new;
end;
$$;

revoke all on function private.mark_document_request_uploaded() from public;

drop trigger if exists mark_document_request_uploaded
  on public.verification_document_versions;
create trigger mark_document_request_uploaded
after insert on public.verification_document_versions
for each row execute function private.mark_document_request_uploaded();

create or replace function private.mark_selfie_request_uploaded()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.identity_selfie_path is distinct from old.identity_selfie_path
     and new.identity_selfie_path is not null then
    update public.verification_document_requests
    set status = 'uploaded', completed_at = now(), updated_at = now()
    where profile_id = new.id
      and document_type = 'identity_selfie'
      and status = 'requested';
  end if;

  if new.guardian_identity_selfie_path is distinct from old.guardian_identity_selfie_path
     and new.guardian_identity_selfie_path is not null then
    update public.verification_document_requests
    set status = 'uploaded', completed_at = now(), updated_at = now()
    where profile_id = new.id
      and document_type = 'guardian_identity_selfie'
      and status = 'requested';
  end if;
  return new;
end;
$$;

revoke all on function private.mark_selfie_request_uploaded() from public;

drop trigger if exists mark_selfie_request_uploaded on public.profiles;
create trigger mark_selfie_request_uploaded
after update of identity_selfie_path, guardian_identity_selfie_path
on public.profiles
for each row execute function private.mark_selfie_request_uploaded();
