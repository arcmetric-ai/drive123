create or replace function public.accept_learner_request_first_claim(target_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  current_profile_id uuid;
  initial_learner_id uuid;
  target_request public.learner_requests%rowtype;
  accepted_request public.learner_requests%rowtype;
  cancelled_count integer := 0;
begin
  current_profile_id := auth.uid();
  if current_profile_id is null then
    raise exception 'not_authenticated';
  end if;

  select learner_id
    into initial_learner_id
  from public.learner_requests
  where id = target_request_id
    and instructor_id = current_profile_id;

  if initial_learner_id is null then
    raise exception 'request_not_found';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(initial_learner_id::text, 0));

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
    for update
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

grant execute on function public.accept_learner_request_first_claim(uuid) to authenticated;
