create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  fcm_token text not null unique,
  platform text not null check (platform in ('ios', 'android', 'web', 'macos')),
  app_version text,
  device_label text,
  is_active boolean not null default true,
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists device_tokens_profile_idx
  on public.device_tokens (profile_id, is_active, last_seen_at desc);

create table if not exists public.notification_preferences (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  fcm_enabled boolean not null default true,
  email_enabled boolean not null default true,
  lesson_updates_enabled boolean not null default true,
  review_updates_enabled boolean not null default true,
  pass_updates_enabled boolean not null default true,
  support_updates_enabled boolean not null default true,
  marketing_enabled boolean not null default false,
  quiet_hours_start time,
  quiet_hours_end time,
  timezone text not null default 'America/Toronto',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notification_events (
  id uuid primary key default gen_random_uuid(),
  event_key text not null,
  recipient_profile_id uuid not null references public.profiles(id) on delete cascade,
  actor_profile_id uuid references public.profiles(id) on delete set null,
  entity_type text,
  entity_id uuid,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  channels text[] not null default array['fcm']::text[],
  priority text not null default 'normal' check (priority in ('low', 'normal', 'high')),
  status text not null default 'queued'
    check (status in ('queued', 'processing', 'sent', 'partial', 'failed', 'cancelled')),
  scheduled_for timestamptz not null default now(),
  processed_at timestamptz,
  dedupe_key text,
  error_message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists notification_events_dedupe_idx
  on public.notification_events (dedupe_key)
  where dedupe_key is not null;

create index if not exists notification_events_recipient_idx
  on public.notification_events (recipient_profile_id, created_at desc);

create index if not exists notification_events_status_idx
  on public.notification_events (status, scheduled_for);

create table if not exists public.notification_deliveries (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.notification_events(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  channel text not null check (channel in ('fcm', 'email')),
  destination text,
  status text not null default 'pending'
    check (status in ('pending', 'sent', 'failed', 'skipped')),
  provider_message_id text,
  error_message text,
  attempts integer not null default 0 check (attempts >= 0),
  sent_at timestamptz,
  opened_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists notification_deliveries_event_idx
  on public.notification_deliveries (event_id);

create index if not exists notification_deliveries_profile_idx
  on public.notification_deliveries (profile_id, created_at desc);

alter table public.device_tokens enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notification_events enable row level security;
alter table public.notification_deliveries enable row level security;

drop policy if exists "users can manage own device tokens"
  on public.device_tokens;
create policy "users can manage own device tokens"
on public.device_tokens
for all
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

drop policy if exists "users can read own notification preferences"
  on public.notification_preferences;
create policy "users can read own notification preferences"
on public.notification_preferences
for select
to authenticated
using (profile_id = auth.uid());

drop policy if exists "users can insert own notification preferences"
  on public.notification_preferences;
create policy "users can insert own notification preferences"
on public.notification_preferences
for insert
to authenticated
with check (profile_id = auth.uid());

drop policy if exists "users can update own notification preferences"
  on public.notification_preferences;
create policy "users can update own notification preferences"
on public.notification_preferences
for update
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

drop policy if exists "users can read own notification events"
  on public.notification_events;
create policy "users can read own notification events"
on public.notification_events
for select
to authenticated
using (recipient_profile_id = auth.uid());

drop policy if exists "users can read own notification deliveries"
  on public.notification_deliveries;
create policy "users can read own notification deliveries"
on public.notification_deliveries
for select
to authenticated
using (profile_id = auth.uid());
