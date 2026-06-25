create or replace function public.register_device_token(
  p_fcm_token text,
  p_platform text,
  p_app_version text default null,
  p_device_label text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid := auth.uid();
  v_token text := nullif(trim(p_fcm_token), '');
  v_platform text := lower(nullif(trim(p_platform), ''));
begin
  if v_profile_id is null then
    raise exception 'Authentication required';
  end if;

  if v_token is null or length(v_token) < 20 or length(v_token) > 4096 then
    raise exception 'Invalid device token';
  end if;

  if v_platform is null or v_platform not in ('ios', 'android', 'web', 'macos') then
    raise exception 'Invalid device platform';
  end if;

  insert into public.device_tokens (
    profile_id,
    fcm_token,
    platform,
    app_version,
    device_label,
    is_active,
    revoked_at,
    last_seen_at,
    updated_at
  )
  values (
    v_profile_id,
    v_token,
    v_platform,
    nullif(trim(p_app_version), ''),
    nullif(trim(p_device_label), ''),
    true,
    null,
    now(),
    now()
  )
  on conflict (fcm_token) do update
    set profile_id = excluded.profile_id,
        platform = excluded.platform,
        app_version = excluded.app_version,
        device_label = excluded.device_label,
        is_active = true,
        revoked_at = null,
        last_seen_at = now(),
        updated_at = now();
end;
$$;

revoke all on function public.register_device_token(text, text, text, text)
  from public, anon;
grant execute on function public.register_device_token(text, text, text, text)
  to authenticated;
