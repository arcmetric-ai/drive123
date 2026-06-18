alter table public.profiles
  drop constraint if exists profiles_verification_status_check;

alter table public.profiles
  add constraint profiles_verification_status_check
  check (
    verification_status is null
    or verification_status in (
      'pending',
      'approved',
      'rejected',
      'referral_approved'
    )
  );

alter table public.learner_profiles
  add column if not exists referral_source_instructor_id uuid references public.profiles(id) on delete set null,
  add column if not exists referral_connected_at timestamptz,
  add column if not exists referral_open_search_unlocked_at timestamptz;

create index if not exists learner_profiles_referral_source_idx
  on public.learner_profiles(referral_source_instructor_id);

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
  existing_active_instructor_id uuid;
  target_request public.learner_requests%rowtype;
  weekly_count integer := 0;
  location_count integer := 0;
begin
  current_profile_id := auth.uid();
  if current_profile_id is null then
    raise exception 'not_authenticated';
  end if;

  normalized_code := upper(regexp_replace(coalesce(entered_code, ''), '[^A-Za-z0-9]', '', 'g'));
  if length(normalized_code) <> 8 then
    raise exception 'invalid_referral_code';
  end if;
  normalized_code := substring(normalized_code from 1 for 2) || '-' || substring(normalized_code from 3);

  select ip.profile_id
    into instructor_profile_id
  from public.instructor_profiles ip
  join public.profiles p on p.id = ip.profile_id
  where upper(ip.drive_tutor_number) = normalized_code
    and p.role = 'instructor'
    and p.is_verified = true
    and ip.credentials_status = 'approved'
  limit 1;

  if instructor_profile_id is null then
    raise exception 'instructor_code_not_found';
  end if;

  if instructor_profile_id = current_profile_id then
    raise exception 'cannot_claim_own_code';
  end if;

  select lr.instructor_id
    into existing_active_instructor_id
  from public.learner_requests lr
  where lr.learner_id = current_profile_id
    and lr.status in ('accepted', 'active', 'in_progress')
    and lr.instructor_id <> instructor_profile_id
  limit 1;

  if existing_active_instructor_id is not null then
    raise exception 'learner_already_connected';
  end if;

  select
    case
      when jsonb_typeof(to_jsonb(lp.weekly_availability)) = 'array'
        then jsonb_array_length(to_jsonb(lp.weekly_availability))
      when jsonb_typeof(to_jsonb(lp.weekly_availability)) = 'object'
        then (
          select count(*)
          from jsonb_each(to_jsonb(lp.weekly_availability)) as slots(day_key, day_slots)
          where jsonb_typeof(day_slots) = 'array'
            and jsonb_array_length(day_slots) > 0
        )
      else 0
    end,
    case
      when jsonb_typeof(to_jsonb(lp.preferred_locations)) = 'array'
        then jsonb_array_length(to_jsonb(lp.preferred_locations))
      else 0
    end
    into weekly_count, location_count
  from public.profiles p
  join public.learner_profiles lp on lp.profile_id = p.id
  where p.id = current_profile_id
    and p.role = 'learner'
    and nullif(trim(coalesce(p.first_name, '')), '') is not null
    and nullif(trim(coalesce(p.last_name, '')), '') is not null
    and nullif(trim(coalesce(p.profile_image_url, '')), '') is not null
    and nullif(trim(coalesce(p.gender, '')), '') is not null
    and p.age is not null
    and nullif(trim(coalesce(p.city, '')), '') is not null;

  if not found or weekly_count <= 0 or location_count <= 0 then
    raise exception 'referral_profile_incomplete';
  end if;

  update public.learner_profiles
  set referral_source_instructor_id = instructor_profile_id,
      referral_connected_at = coalesce(referral_connected_at, now())
  where profile_id = current_profile_id;

  update public.profiles
  set is_verified = true,
      verification_status = 'referral_approved',
      verification_approved_at = coalesce(verification_approved_at, now()),
      onboarding_stage = 'questionnaire_complete',
      updated_at = now()
  where id = current_profile_id;

  update public.learner_requests
  set status = 'cancelled',
      updated_at = now()
  where learner_id = current_profile_id
    and instructor_id <> instructor_profile_id
    and status = 'pending';

  select *
    into target_request
  from public.learner_requests
  where learner_id = current_profile_id
    and instructor_id = instructor_profile_id
    and status in ('pending', 'accepted', 'active', 'in_progress')
  order by updated_at desc nulls last, created_at desc
  limit 1;

  if target_request.id is null then
    insert into public.learner_requests (
      instructor_id,
      learner_id,
      focus,
      message,
      status,
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
      null,
      'Added using instructor referral code.',
      'accepted',
      p.first_name,
      p.last_name,
      p.profile_image_url,
      p.phone,
      p.gender,
      p.city,
      p.age
    from public.profiles p
    where p.id = current_profile_id
    returning * into target_request;
  else
    update public.learner_requests
    set status = 'accepted',
        message = coalesce(nullif(message, ''), 'Added using instructor referral code.'),
        updated_at = now()
    where id = target_request.id
    returning * into target_request;
  end if;

  return jsonb_build_object(
    'status', 'accepted',
    'instructorId', instructor_profile_id,
    'request', to_jsonb(target_request)
  );
end;
$$;

create or replace function public.accept_learner_request_first_claim(target_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_profile_id uuid;
  target_request public.learner_requests%rowtype;
  accepted_request public.learner_requests%rowtype;
  cancelled_count integer := 0;
begin
  current_profile_id := auth.uid();
  if current_profile_id is null then
    raise exception 'not_authenticated';
  end if;

  select *
    into target_request
  from public.learner_requests
  where id = target_request_id
    and instructor_id = current_profile_id
  for update;

  if target_request.id is null then
    raise exception 'request_not_found';
  end if;

  if target_request.status = 'accepted' then
    return jsonb_build_object(
      'request', to_jsonb(target_request),
      'cancelledOtherCount', 0
    );
  end if;

  if target_request.status <> 'pending' then
    raise exception 'request_not_pending';
  end if;

  if exists (
    select 1
    from public.learner_requests lr
    where lr.learner_id = target_request.learner_id
      and lr.instructor_id <> current_profile_id
      and lr.status in ('accepted', 'active', 'in_progress')
  ) then
    update public.learner_requests
    set status = 'cancelled',
        updated_at = now()
    where id = target_request.id;

    raise exception 'learner_already_connected';
  end if;

  update public.learner_requests
  set status = 'accepted',
      updated_at = now()
  where id = target_request.id
  returning * into accepted_request;

  update public.learner_requests
  set status = 'cancelled',
      updated_at = now()
  where learner_id = accepted_request.learner_id
    and id <> accepted_request.id
    and status = 'pending';

  get diagnostics cancelled_count = row_count;

  return jsonb_build_object(
    'request', to_jsonb(accepted_request),
    'cancelledOtherCount', cancelled_count
  );
end;
$$;

create or replace function public.remove_current_learner_instructor(target_instructor_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_profile_id uuid;
  removed_count integer := 0;
  active_count integer := 0;
  requires_verification boolean := false;
begin
  current_profile_id := auth.uid();
  if current_profile_id is null then
    raise exception 'not_authenticated';
  end if;

  update public.learner_requests
  set status = 'removed',
      updated_at = now()
  where learner_id = current_profile_id
    and instructor_id = target_instructor_id
    and status in ('accepted', 'active', 'in_progress');

  get diagnostics removed_count = row_count;

  update public.lessons
  set status = 'cancelled'
  where learner_id = current_profile_id
    and instructor_id = target_instructor_id
    and status = 'scheduled';

  select count(*)
    into active_count
  from public.learner_requests
  where learner_id = current_profile_id
    and status in ('accepted', 'active', 'in_progress');

  if active_count = 0 and exists (
    select 1
    from public.profiles p
    where p.id = current_profile_id
      and p.role = 'learner'
      and p.verification_status = 'referral_approved'
  ) then
    update public.profiles
    set is_verified = false,
        verification_status = null,
        verification_approved_at = null,
        updated_at = now()
    where id = current_profile_id;

    update public.learner_profiles
    set referral_open_search_unlocked_at = now()
    where profile_id = current_profile_id;

    requires_verification := true;
  end if;

  return jsonb_build_object(
    'removed', removed_count > 0,
    'requiresVerification', requires_verification
  );
end;
$$;

grant execute on function public.claim_instructor_referral_code(text) to authenticated;
grant execute on function public.accept_learner_request_first_claim(uuid) to authenticated;
grant execute on function public.remove_current_learner_instructor(uuid) to authenticated;
