create or replace function public.claim_instructor_referral_code(entered_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_code text;
  current_profile_id uuid;
  instructor_profile_id uuid;
  existing_request record;
  inserted_request record;
  found_existing boolean := false;
begin
  current_profile_id := auth.uid();
  if current_profile_id is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  normalized_code := upper(regexp_replace(coalesce(entered_code, ''), '[^A-Za-z0-9]', '', 'g'));
  if length(normalized_code) <> 8 then
    raise exception 'invalid_referral_code' using errcode = '22023';
  end if;
  normalized_code := substr(normalized_code, 1, 2) || '-' || substr(normalized_code, 3);

  select ip.profile_id
    into instructor_profile_id
  from public.instructor_profiles ip
  join public.profiles p on p.id = ip.profile_id
  where upper(ip.drive_tutor_number) = normalized_code
    and coalesce(p.role, '') = 'instructor'
    and coalesce(p.is_verified, false) = true
    and coalesce(ip.credentials_status, '') = 'approved'
  limit 1;

  if instructor_profile_id is null then
    raise exception 'instructor_referral_not_found' using errcode = 'P0002';
  end if;

  if instructor_profile_id = current_profile_id then
    raise exception 'cannot_claim_own_referral' using errcode = '22023';
  end if;

  if not exists (
    select 1
    from public.profiles p
    left join public.learner_profiles lp on lp.profile_id = p.id
    where p.id = current_profile_id
      and coalesce(p.role, '') = 'learner'
      and coalesce(p.is_verified, false) = true
      and lp.profile_id is not null
  ) then
    raise exception 'learner_not_approved' using errcode = '42501';
  end if;

  select *
    into existing_request
  from public.learner_requests lr
  where lr.learner_id = current_profile_id
    and lr.instructor_id = instructor_profile_id
    and lr.status in ('pending', 'accepted', 'active', 'in_progress')
  order by lr.updated_at desc nulls last, lr.created_at desc nulls last
  limit 1;
  found_existing := found;

  if found_existing then
    if existing_request.status <> 'accepted' then
      update public.learner_requests
      set status = 'accepted',
          message = coalesce(nullif(message, ''), 'Added using instructor referral code.'),
          updated_at = now()
      where id = existing_request.id
      returning * into inserted_request;
    else
      inserted_request := existing_request;
    end if;
  else
    insert into public.learner_requests (
      instructor_id,
      learner_id,
      status,
      focus,
      message,
      requested_first_name,
      requested_last_name,
      requested_profile_url,
      requested_phone,
      requested_gender,
      requested_city,
      requested_age
    )
    select
      instructor_profile_id,
      p.id,
      'accepted',
      null,
      'Added using instructor referral code.',
      nullif(trim(coalesce(p.first_name, '')), ''),
      nullif(trim(coalesce(p.last_name, '')), ''),
      nullif(trim(coalesce(p.profile_image_url, '')), ''),
      nullif(trim(coalesce(p.phone, '')), ''),
      nullif(trim(coalesce(p.gender, '')), ''),
      nullif(trim(coalesce(p.city, '')), ''),
      p.age
    from public.profiles p
    where p.id = current_profile_id
    returning * into inserted_request;
  end if;

  return jsonb_build_object(
    'requestId', inserted_request.id,
    'status', inserted_request.status,
    'instructorId', instructor_profile_id,
    'instructorCode', normalized_code
  );
end;
$$;

revoke all on function public.claim_instructor_referral_code(text) from public;
grant execute on function public.claim_instructor_referral_code(text) to authenticated;
