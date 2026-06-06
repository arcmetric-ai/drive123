create extension if not exists pgcrypto;

create table if not exists public.signup_flows (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique,
  email text not null,
  flow_token_hash text not null unique,
  confirmed_at timestamptz,
  completed_at timestamptz,
  expires_at timestamptz not null default (now() + interval '2 days'),
  created_at timestamptz not null default now()
);

alter table public.signup_flows enable row level security;

drop policy if exists "no direct access to signup flows" on public.signup_flows;

create policy "no direct access to signup flows"
on public.signup_flows
for all
using (false)
with check (false);
