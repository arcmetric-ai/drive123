create table if not exists public.legal_holds (
  id uuid primary key default gen_random_uuid(),
  subject_profile_id uuid references public.profiles(id) on delete set null,
  entity_table text,
  entity_id uuid,
  reason_type text not null
    check (reason_type in (
      'safety_matter',
      'dispute',
      'police_request',
      'insurance_matter',
      'chargeback',
      'litigation',
      'privacy_request',
      'other'
    )),
  status text not null default 'active'
    check (status in ('active', 'released')),
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  released_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  released_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  constraint legal_holds_subject_or_entity_required
    check (subject_profile_id is not null or (entity_table is not null and entity_id is not null)),
  constraint legal_holds_released_fields
    check (
      (status = 'active' and released_at is null)
      or (status = 'released' and released_at is not null)
    )
);

create index if not exists legal_holds_subject_status_idx
  on public.legal_holds (subject_profile_id, status, created_at desc);

create index if not exists legal_holds_entity_status_idx
  on public.legal_holds (entity_table, entity_id, status, created_at desc);

alter table public.legal_holds enable row level security;
revoke all on public.legal_holds from public, anon, authenticated;
grant select, insert, update on public.legal_holds to service_role;

alter table public.account_deletion_requests
  add column if not exists processing_started_at timestamptz,
  add column if not exists processing_completed_at timestamptz,
  add column if not exists retained_reason text,
  add column if not exists anonymized_at timestamptz,
  add column if not exists deletion_version text not null default '2026-06-24';

create table if not exists public.account_deletion_processing_items (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.account_deletion_requests(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  category text not null,
  target_table text not null,
  target_id uuid,
  action text not null check (action in ('delete', 'anonymize', 'retain', 'manual_review')),
  reason text not null,
  eligible_after timestamptz,
  status text not null default 'pending'
    check (status in ('pending', 'blocked_by_legal_hold', 'completed', 'skipped', 'failed')),
  created_at timestamptz not null default now(),
  processed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists account_deletion_processing_items_request_idx
  on public.account_deletion_processing_items (request_id, status, created_at);

create index if not exists account_deletion_processing_items_profile_idx
  on public.account_deletion_processing_items (profile_id, category, status);

alter table public.account_deletion_processing_items enable row level security;
revoke all on public.account_deletion_processing_items from public, anon, authenticated;
grant select, insert, update on public.account_deletion_processing_items to service_role;

create table if not exists public.security_safeguard_breach_records (
  id uuid primary key default gen_random_uuid(),
  detected_at timestamptz not null default now(),
  occurred_at timestamptz,
  severity text not null default 'under_review'
    check (severity in ('under_review', 'low', 'medium', 'high', 'critical')),
  status text not null default 'open'
    check (status in ('open', 'contained', 'notifiable', 'reported', 'closed')),
  summary text not null,
  affected_profile_ids uuid[] not null default '{}'::uuid[],
  retained_until timestamptz not null default (now() + interval '2 years'),
  created_by uuid references auth.users(id) on delete set null,
  closed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  constraint security_breach_retention_minimum
    check (retained_until >= coalesce(occurred_at, detected_at) + interval '2 years')
);

create index if not exists security_breach_records_status_idx
  on public.security_safeguard_breach_records (status, detected_at desc);

create index if not exists security_breach_records_retained_until_idx
  on public.security_safeguard_breach_records (retained_until);

alter table public.security_safeguard_breach_records enable row level security;
revoke all on public.security_safeguard_breach_records from public, anon, authenticated;
grant select, insert, update on public.security_safeguard_breach_records to service_role;

create table if not exists public.retention_processing_runs (
  id uuid primary key default gen_random_uuid(),
  status text not null default 'planned'
    check (status in ('planned', 'running', 'completed', 'failed', 'cancelled')),
  dry_run boolean not null default true,
  started_at timestamptz,
  completed_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  summary jsonb not null default '{}'::jsonb,
  error_message text,
  created_at timestamptz not null default now()
);

alter table public.retention_processing_runs enable row level security;
revoke all on public.retention_processing_runs from public, anon, authenticated;
grant select, insert, update on public.retention_processing_runs to service_role;

create or replace function private.profile_has_active_legal_hold(p_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.legal_holds hold
    where hold.status = 'active'
      and hold.subject_profile_id = p_profile_id
  )
  or exists (
    select 1
    from public.account_deletion_requests request
    where request.profile_id = p_profile_id
      and request.legal_hold = true
      and request.status in ('requested', 'in_review')
  );
$$;

create or replace function private.entity_has_active_legal_hold(
  p_entity_table text,
  p_entity_id uuid,
  p_profile_id uuid default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.legal_holds hold
    where hold.status = 'active'
      and (
        (hold.entity_table = p_entity_table and hold.entity_id = p_entity_id)
        or (p_profile_id is not null and hold.subject_profile_id = p_profile_id)
      )
  )
  or (p_profile_id is not null and private.profile_has_active_legal_hold(p_profile_id));
$$;

create or replace function private.enqueue_account_deletion_processing_items(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.account_deletion_requests%rowtype;
  v_blocked boolean;
begin
  select *
    into v_request
  from public.account_deletion_requests
  where id = p_request_id;

  if not found then
    raise exception 'Account deletion request not found';
  end if;

  v_blocked := private.profile_has_active_legal_hold(v_request.profile_id);

  insert into public.account_deletion_processing_items (
    request_id,
    profile_id,
    category,
    target_table,
    action,
    reason,
    status,
    metadata
  )
  values
    (
      p_request_id,
      v_request.profile_id,
      'account_profile',
      'profiles',
      case when v_blocked then 'retain' else 'anonymize' end,
      case when v_blocked
        then 'Active legal hold blocks profile anonymization.'
        else 'Profile is anonymized instead of hard-deleted to preserve required audit references.'
      end,
      case when v_blocked then 'blocked_by_legal_hold' else 'pending' end,
      jsonb_build_object('deletion_version', v_request.deletion_version)
    ),
    (
      p_request_id,
      v_request.profile_id,
      'consent_records',
      'user_agreements',
      'retain',
      'Consent records are retained for policy acceptance history and legal compliance.',
      'pending',
      jsonb_build_object('deletion_version', v_request.deletion_version)
    ),
    (
      p_request_id,
      v_request.profile_id,
      'verification_records',
      'verification_document_versions',
      'manual_review',
      'Verification records require category-specific retention review before deletion.',
      case when v_blocked then 'blocked_by_legal_hold' else 'pending' end,
      jsonb_build_object('deletion_version', v_request.deletion_version)
    ),
    (
      p_request_id,
      v_request.profile_id,
      'lesson_records',
      'lessons',
      'manual_review',
      'Lesson and safety records may need retention for disputes, insurance, minors, or safety matters.',
      case when v_blocked then 'blocked_by_legal_hold' else 'pending' end,
      jsonb_build_object('deletion_version', v_request.deletion_version)
    ),
    (
      p_request_id,
      v_request.profile_id,
      'notification_logs',
      'notification_events',
      'delete',
      'Notification logs are eligible for deletion after their retention period unless held.',
      case when v_blocked then 'blocked_by_legal_hold' else 'pending' end,
      jsonb_build_object('deletion_version', v_request.deletion_version)
    )
  on conflict do nothing;
end;
$$;

create or replace function private.enqueue_account_deletion_processing_items_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.enqueue_account_deletion_processing_items(new.id);
  return new;
end;
$$;

drop trigger if exists enqueue_account_deletion_processing_items
  on public.account_deletion_requests;
create trigger enqueue_account_deletion_processing_items
  after insert on public.account_deletion_requests
  for each row execute function private.enqueue_account_deletion_processing_items_trigger();

create or replace function private.retention_candidates(p_now timestamptz default now())
returns table (
  category text,
  target_table text,
  target_id uuid,
  profile_id uuid,
  action text,
  eligible_after timestamptz,
  blocked_by_legal_hold boolean,
  reason text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    'notification_event'::text,
    'notification_events'::text,
    event.id,
    event.recipient_profile_id,
    'delete'::text,
    event.created_at + interval '1 year',
    private.entity_has_active_legal_hold('notification_events', event.id, event.recipient_profile_id),
    'Notification event log exceeds 1 year retention.'
  from public.notification_events event
  where event.created_at < p_now - interval '1 year'

  union all

  select
    'notification_delivery'::text,
    'notification_deliveries'::text,
    delivery.id,
    delivery.profile_id,
    'delete'::text,
    delivery.created_at + interval '1 year',
    private.entity_has_active_legal_hold('notification_deliveries', delivery.id, delivery.profile_id),
    'Notification delivery log exceeds 1 year retention.'
  from public.notification_deliveries delivery
  where delivery.created_at < p_now - interval '1 year'

  union all

  select
    'expired_device_token'::text,
    'device_tokens'::text,
    token.id,
    token.profile_id,
    'delete'::text,
    coalesce(token.revoked_at, token.last_seen_at) + interval '90 days',
    private.entity_has_active_legal_hold('device_tokens', token.id, token.profile_id),
    'Inactive device token exceeds retention window.'
  from public.device_tokens token
  where token.is_active = false
    and coalesce(token.revoked_at, token.last_seen_at) < p_now - interval '90 days'

  union all

  select
    'abandoned_verification_request'::text,
    'verification_document_requests'::text,
    request.id,
    request.profile_id,
    'delete'::text,
    request.created_at + interval '90 days',
    private.entity_has_active_legal_hold('verification_document_requests', request.id, request.profile_id),
    'Uncompleted verification document request exceeds abandoned-request retention window.'
  from public.verification_document_requests request
  where request.status in ('requested', 'cancelled')
    and request.created_at < p_now - interval '90 days'

  union all

  select
    'rejected_verification_application'::text,
    'profiles'::text,
    profile.id,
    profile.id,
    'manual_review'::text,
    profile.verification_rejected_at + interval '1 year',
    private.profile_has_active_legal_hold(profile.id),
    'Rejected verification profile exceeds review window and requires category-specific retention review.'
  from public.profiles profile
  where profile.verification_status = 'rejected'
    and profile.verification_rejected_at is not null
    and profile.verification_rejected_at < p_now - interval '1 year';
$$;

revoke all on function private.profile_has_active_legal_hold(uuid) from public, anon, authenticated;
revoke all on function private.entity_has_active_legal_hold(text, uuid, uuid) from public, anon, authenticated;
revoke all on function private.enqueue_account_deletion_processing_items(uuid) from public, anon, authenticated;
revoke all on function private.retention_candidates(timestamptz) from public, anon, authenticated;

alter table public.profiles
  drop constraint if exists profiles_role_age_policy_check;

alter table public.profiles
  add constraint profiles_role_age_policy_check
  check (
    role is null
    or (role = 'instructor' and age is not null and age >= 21 and age <= 100)
    or (role = 'learner' and (age is null or (age >= 18 and age <= 100)))
  ) not valid;

alter table public.learner_profiles
  drop constraint if exists learner_profiles_guardian_ward_age_policy_check;

alter table public.learner_profiles
  add constraint learner_profiles_guardian_ward_age_policy_check
  check (
    account_type is distinct from 'guardian'
    or (ward_age is not null and ward_age between 16 and 17)
  ) not valid;

create or replace function private.prevent_profile_role_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE'
    and old.role is not null
    and new.role is distinct from old.role then
    raise exception 'Account role cannot be changed after signup';
  end if;
  return new;
end;
$$;

drop trigger if exists prevent_profile_role_mutation
  on public.profiles;
create trigger prevent_profile_role_mutation
  before update on public.profiles
  for each row execute function private.prevent_profile_role_mutation();
