create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

alter table public.user_agreements
  add column if not exists policy_url text,
  add column if not exists policy_hash text,
  add column if not exists source text,
  add column if not exists role text;

create unique index if not exists user_agreements_profile_key_version_idx
  on public.user_agreements (profile_id, agreement_key, agreement_version);

create or replace function private.normalize_ontario_licence_number(p_value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_value is null then null
    else nullif(upper(regexp_replace(trim(p_value), '[^A-Za-z0-9]', '', 'g')), '')
  end;
$$;

create or replace function public.normalize_ontario_licence_number(p_value text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select private.normalize_ontario_licence_number(p_value);
$$;

revoke all on function public.normalize_ontario_licence_number(text)
  from public, anon;
grant execute on function public.normalize_ontario_licence_number(text)
  to authenticated, service_role;

alter table public.profiles
  add column if not exists licence_number_normalized text;

alter table public.profiles
  drop constraint if exists profiles_ontario_licence_number_format_check;

alter table public.profiles
  add constraint profiles_ontario_licence_number_format_check
  check (
    licence_number is null
    or trim(licence_number) = ''
    or licence_number_normalized ~ '^[A-Z][0-9]{14}$'
  ) not valid;

create unique index if not exists profiles_licence_number_normalized_unique_idx
  on public.profiles (licence_number_normalized)
  where licence_number_normalized is not null;

create or replace function private.prevent_locked_profile_licence_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT'
    or new.licence_number is distinct from old.licence_number then
    new.licence_number_normalized :=
      private.normalize_ontario_licence_number(new.licence_number);
  end if;

  if tg_op = 'UPDATE'
    and old.verification_submitted_at is not null
    and old.licence_number_normalized is not null
    and new.licence_number_normalized is distinct from old.licence_number_normalized then
    raise exception 'Licence number cannot be changed after verification is submitted';
  end if;

  if (tg_op = 'INSERT'
      or new.licence_expiry is distinct from old.licence_expiry)
    and new.licence_expiry is not null
    and new.licence_expiry::date < current_date then
    raise exception 'Licence expiry cannot be in the past';
  end if;

  return new;
end;
$$;

drop trigger if exists prevent_locked_profile_licence_mutation
  on public.profiles;
create trigger prevent_locked_profile_licence_mutation
  before insert or update of licence_number, licence_expiry on public.profiles
  for each row execute function private.prevent_locked_profile_licence_mutation();

create or replace function public.is_licence_number_available(p_licence_number text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_normalized text := private.normalize_ontario_licence_number(p_licence_number);
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if v_normalized is null or v_normalized !~ '^[A-Z][0-9]{14}$' then
    return false;
  end if;

  return not exists (
    select 1
    from public.profiles profile
    where coalesce(
        profile.licence_number_normalized,
        private.normalize_ontario_licence_number(profile.licence_number)
      ) = v_normalized
      and profile.id <> auth.uid()
  );
end;
$$;

revoke all on function public.is_licence_number_available(text)
  from public, anon;
grant execute on function public.is_licence_number_available(text)
  to authenticated;

grant execute on function private.normalize_ontario_licence_number(text)
  to service_role;
