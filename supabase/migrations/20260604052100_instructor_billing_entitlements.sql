create table if not exists public.instructor_billing_plans (
  plan_key text primary key,
  display_name text not null,
  description text,
  amount_cents integer not null check (amount_cents > 0),
  currency text not null default 'cad',
  billing_interval text not null check (
    billing_interval in ('day', 'month', 'year')
  ),
  access_days integer not null check (access_days > 0),
  stripe_price_env text not null,
  feature_codes text[] not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.instructor_stripe_customers (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  stripe_customer_id text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.instructor_billing_entitlements (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  plan_key text not null references public.instructor_billing_plans(plan_key),
  status text not null check (
    status in (
      'active',
      'trialing',
      'past_due',
      'incomplete',
      'canceled',
      'expired'
    )
  ),
  stripe_customer_id text,
  stripe_subscription_id text,
  stripe_checkout_session_id text,
  stripe_payment_intent_id text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  access_starts_at timestamptz not null default now(),
  access_expires_at timestamptz not null,
  cancel_at_period_end boolean not null default false,
  last_stripe_event_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (access_expires_at > access_starts_at)
);

create unique index if not exists instructor_billing_entitlements_subscription_idx
  on public.instructor_billing_entitlements (stripe_subscription_id)
  where stripe_subscription_id is not null;

create unique index if not exists instructor_billing_entitlements_checkout_idx
  on public.instructor_billing_entitlements (stripe_checkout_session_id)
  where stripe_checkout_session_id is not null;

create index if not exists instructor_billing_entitlements_access_idx
  on public.instructor_billing_entitlements (profile_id, status, access_expires_at);

create table if not exists public.stripe_webhook_events (
  event_id text primary key,
  event_type text not null,
  processed_at timestamptz not null default now()
);

alter table public.instructor_billing_plans enable row level security;
alter table public.instructor_stripe_customers enable row level security;
alter table public.instructor_billing_entitlements enable row level security;
alter table public.stripe_webhook_events enable row level security;

drop policy if exists "billing plans are readable by authenticated users"
  on public.instructor_billing_plans;
create policy "billing plans are readable by authenticated users"
on public.instructor_billing_plans
for select
to authenticated
using (is_active);

drop policy if exists "instructors can read own stripe customer"
  on public.instructor_stripe_customers;
create policy "instructors can read own stripe customer"
on public.instructor_stripe_customers
for select
to authenticated
using (profile_id = auth.uid());

drop policy if exists "instructors can read own billing entitlement"
  on public.instructor_billing_entitlements;
create policy "instructors can read own billing entitlement"
on public.instructor_billing_entitlements
for select
to authenticated
using (profile_id = auth.uid());

create or replace function public.instructor_has_active_billing(
  target_profile_id uuid default auth.uid()
)
returns boolean
language sql
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.instructor_billing_entitlements entitlement
    where entitlement.profile_id = target_profile_id
      and entitlement.status in ('active', 'trialing')
      and entitlement.access_starts_at <= now()
      and entitlement.access_expires_at > now()
  );
$$;

create or replace function public.current_user_passes_instructor_billing_gate()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select profile.role::text
    from public.profiles profile
    where profile.id = auth.uid()
  ), '') <> 'instructor'
  or exists (
    select 1
    from public.instructor_billing_entitlements entitlement
    where entitlement.profile_id = auth.uid()
      and entitlement.status in ('active', 'trialing')
      and entitlement.access_starts_at <= now()
      and entitlement.access_expires_at > now()
  );
$$;

grant execute on function public.instructor_has_active_billing(uuid)
  to authenticated;
grant execute on function public.current_user_passes_instructor_billing_gate()
  to authenticated;

do $$
begin
  if to_regclass('public.instructor_availability') is not null then
    execute 'alter table public.instructor_availability enable row level security';
    execute 'drop policy if exists "billing required for instructor availability" on public.instructor_availability';
    execute 'create policy "billing required for instructor availability"
      on public.instructor_availability
      as restrictive
      for all
      to authenticated
      using (public.current_user_passes_instructor_billing_gate())
      with check (public.current_user_passes_instructor_billing_gate())';
  end if;

  if to_regclass('public.instructor_availability_blocks') is not null then
    execute 'alter table public.instructor_availability_blocks enable row level security';
    execute 'drop policy if exists "billing required for instructor availability blocks" on public.instructor_availability_blocks';
    execute 'create policy "billing required for instructor availability blocks"
      on public.instructor_availability_blocks
      as restrictive
      for all
      to authenticated
      using (public.current_user_passes_instructor_billing_gate())
      with check (public.current_user_passes_instructor_billing_gate())';
  end if;

  if to_regclass('public.learner_requests') is not null then
    execute 'alter table public.learner_requests enable row level security';
    execute 'drop policy if exists "billing required for instructor learner requests" on public.learner_requests';
    execute 'create policy "billing required for instructor learner requests"
      on public.learner_requests
      as restrictive
      for all
      to authenticated
      using (public.current_user_passes_instructor_billing_gate())
      with check (public.current_user_passes_instructor_billing_gate())';
  end if;

  if to_regclass('public.lessons') is not null then
    execute 'alter table public.lessons enable row level security';
    execute 'drop policy if exists "billing required for instructor lessons" on public.lessons';
    execute 'create policy "billing required for instructor lessons"
      on public.lessons
      as restrictive
      for all
      to authenticated
      using (public.current_user_passes_instructor_billing_gate())
      with check (public.current_user_passes_instructor_billing_gate())';
  end if;
end $$;

insert into public.instructor_billing_plans (
  plan_key,
  display_name,
  description,
  amount_cents,
  currency,
  billing_interval,
  access_days,
  stripe_price_env,
  feature_codes
)
values
  (
    'day_pass',
    'Day Pass',
    'Access for one day.',
    1200,
    'cad',
    'day',
    1,
    'STRIPE_PRICE_DAY_PASS',
    array['instructor_access']
  ),
  (
    'monthly_pass',
    'Monthly Pass',
    'Access for one month.',
    30000,
    'cad',
    'month',
    30,
    'STRIPE_PRICE_MONTHLY_PASS',
    array['instructor_access']
  ),
  (
    'yearly_pass',
    'Yearly Pass',
    'Access for one year.',
    328500,
    'cad',
    'year',
    365,
    'STRIPE_PRICE_YEARLY_PASS',
    array['instructor_access']
  )
on conflict (plan_key) do update
set
  display_name = excluded.display_name,
  description = excluded.description,
  amount_cents = excluded.amount_cents,
  currency = excluded.currency,
  billing_interval = excluded.billing_interval,
  access_days = excluded.access_days,
  stripe_price_env = excluded.stripe_price_env,
  feature_codes = excluded.feature_codes,
  is_active = true,
  updated_at = now();
