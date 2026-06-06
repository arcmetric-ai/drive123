create table if not exists public.user_agreements (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  agreement_key text not null,
  agreement_version text not null,
  accepted_at timestamptz not null default now(),
  ip_address inet,
  user_agent text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists user_agreements_profile_idx
  on public.user_agreements (profile_id, agreement_key, accepted_at desc);

create table if not exists public.account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text,
  reason text,
  details text,
  status text not null default 'requested'
    check (status in ('requested', 'in_review', 'completed', 'rejected', 'cancelled')),
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewed_by uuid,
  completed_at timestamptz,
  admin_notes text,
  legal_hold boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists account_deletion_requests_profile_idx
  on public.account_deletion_requests (profile_id, requested_at desc);

create index if not exists account_deletion_requests_status_idx
  on public.account_deletion_requests (status, requested_at desc);

alter table public.user_agreements enable row level security;
alter table public.account_deletion_requests enable row level security;

drop policy if exists "users can insert own agreement records"
  on public.user_agreements;
create policy "users can insert own agreement records"
on public.user_agreements
for insert
to authenticated
with check (profile_id = auth.uid());

drop policy if exists "users can read own agreement records"
  on public.user_agreements;
create policy "users can read own agreement records"
on public.user_agreements
for select
to authenticated
using (profile_id = auth.uid());

drop policy if exists "users can insert own deletion requests"
  on public.account_deletion_requests;
create policy "users can insert own deletion requests"
on public.account_deletion_requests
for insert
to authenticated
with check (profile_id = auth.uid());

drop policy if exists "users can read own deletion requests"
  on public.account_deletion_requests;
create policy "users can read own deletion requests"
on public.account_deletion_requests
for select
to authenticated
using (profile_id = auth.uid());

alter table public.profiles
  add column if not exists verification_rejected_at timestamptz,
  add column if not exists verification_rejection_reason text,
  add column if not exists verification_review_notes text,
  add column if not exists verification_reviewed_by uuid;

alter table public.instructor_profiles
  add column if not exists credentials_rejected_at timestamptz,
  add column if not exists credentials_rejection_reason text,
  add column if not exists credentials_review_notes text,
  add column if not exists credentials_reviewed_by uuid;
