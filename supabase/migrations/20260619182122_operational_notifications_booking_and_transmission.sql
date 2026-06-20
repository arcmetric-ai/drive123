create schema if not exists private;

update public.user_reports
set comment = 'Legacy report submitted before detailed comments were required.'
where comment is null or char_length(trim(comment)) < 25;

alter table public.user_reports
  drop constraint if exists user_reports_comment_required_check;
alter table public.user_reports
  add constraint user_reports_comment_required_check
  check (comment is not null and char_length(trim(comment)) between 25 and 2000);

alter table public.learner_profiles
  add column if not exists transmission_preference text;

alter table public.instructor_profiles
  add column if not exists transmission_preference text;

alter table public.external_learners
  add column if not exists transmission_preference text;

alter table public.learner_profiles
  drop constraint if exists learner_profiles_transmission_preference_check;
alter table public.learner_profiles
  add constraint learner_profiles_transmission_preference_check
  check (transmission_preference is null or transmission_preference in ('automatic', 'manual'));

alter table public.instructor_profiles
  drop constraint if exists instructor_profiles_transmission_preference_check;
alter table public.instructor_profiles
  add constraint instructor_profiles_transmission_preference_check
  check (transmission_preference is null or transmission_preference in ('automatic', 'manual'));

alter table public.external_learners
  drop constraint if exists external_learners_transmission_preference_check;
alter table public.external_learners
  add constraint external_learners_transmission_preference_check
  check (transmission_preference is null or transmission_preference in ('automatic', 'manual'));

drop policy if exists "learners can reactivate graduated relationship"
  on public.learner_requests;
create policy "learners can reactivate graduated relationship"
on public.learner_requests
for update
to authenticated
using (learner_id = auth.uid() and status = 'graduated')
with check (learner_id = auth.uid() and status = 'accepted');

create or replace function private.profile_display_name(target_id uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    nullif(trim(concat_ws(' ', p.first_name, p.last_name)), ''),
    nullif(trim(p.email), ''),
    'Drive Tutor user'
  )
  from public.profiles p
  where p.id = target_id;
$$;

create or replace function private.enqueue_notification(
  target_event_key text,
  target_recipient uuid,
  target_actor uuid,
  target_entity_type text,
  target_entity_id uuid,
  target_title text,
  target_body text,
  target_data jsonb,
  target_priority text,
  target_dedupe_key text,
  target_scheduled_for timestamptz default now()
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if target_recipient is null then
    return;
  end if;

  insert into public.notification_events (
    event_key,
    recipient_profile_id,
    actor_profile_id,
    entity_type,
    entity_id,
    title,
    body,
    data,
    channels,
    priority,
    status,
    scheduled_for,
    dedupe_key
  ) values (
    target_event_key,
    target_recipient,
    target_actor,
    target_entity_type,
    target_entity_id,
    target_title,
    target_body,
    coalesce(target_data, '{}'::jsonb),
    array['fcm']::text[],
    coalesce(target_priority, 'normal'),
    'queued',
    coalesce(target_scheduled_for, now()),
    target_dedupe_key
  )
  on conflict (dedupe_key) where dedupe_key is not null do nothing;
end;
$$;

create or replace function private.queue_learner_request_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  learner_name text := private.profile_display_name(new.learner_id);
  instructor_name text := private.profile_display_name(new.instructor_id);
begin
  if tg_op = 'INSERT' and new.status = 'pending' then
    perform private.enqueue_notification(
      'learner.request.created', new.instructor_id, new.learner_id,
      'learner_request', new.id, 'New learner request',
      learner_name || ' sent you a learner request.',
      jsonb_build_object('route', '/instructor/requests', 'requestId', new.id),
      'high', 'request-created:' || new.id::text
    );
  elsif tg_op = 'INSERT' and new.status in ('accepted', 'active', 'in_progress') then
    perform private.enqueue_notification(
      'learner.referral.added', new.instructor_id, new.learner_id,
      'learner_request', new.id, 'Referred learner added',
      learner_name || ' joined your active learners.',
      jsonb_build_object('route', '/instructor/students', 'requestId', new.id),
      'high', 'referral-added:' || new.id::text
    );
  elsif tg_op = 'UPDATE' and new.status is distinct from old.status then
    if new.status = 'accepted' and old.status = 'pending' then
      perform private.enqueue_notification(
        'learner.request.accepted', new.learner_id, new.instructor_id,
        'learner_request', new.id, 'Request accepted',
        instructor_name || ' accepted your learner request.',
        jsonb_build_object('route', '/learner/instructor', 'requestId', new.id),
        'high', 'request-accepted:' || new.id::text
      );
    elsif new.status in ('rejected', 'declined') then
      perform private.enqueue_notification(
        'learner.request.rejected', new.learner_id, new.instructor_id,
        'learner_request', new.id, 'Request update',
        instructor_name || ' was unable to accept your request.',
        jsonb_build_object('route', '/learner/requests', 'requestId', new.id),
        'normal', 'request-rejected:' || new.id::text
      );
    elsif new.status = 'removed' then
      perform private.enqueue_notification(
        'learner.relationship.left', new.instructor_id, new.learner_id,
        'learner_request', new.id, 'Learner left',
        learner_name || ' left your active learner list.',
        jsonb_build_object('route', '/instructor/students', 'requestId', new.id),
        'high', 'learner-left:' || new.id::text
      );
    elsif new.status = 'graduated' then
      perform private.enqueue_notification(
        'learner.graduated', new.learner_id, new.instructor_id,
        'learner_request', new.id, 'Training marked complete',
        instructor_name || ' marked your current training focus as graduated. You can resume later.',
        jsonb_build_object('route', '/profile', 'requestId', new.id),
        'normal', 'learner-graduated:' || new.id::text
      );
    elsif old.status = 'graduated' and new.status = 'accepted' then
      perform private.enqueue_notification(
        'learner.training.resumed', new.instructor_id, new.learner_id,
        'learner_request', new.id, 'Learner resumed training',
        learner_name || ' resumed training with you.',
        jsonb_build_object('route', '/instructor/students', 'requestId', new.id),
        'normal', 'learner-resumed:' || new.id::text || ':' || extract(epoch from new.updated_at)::bigint::text
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists learner_request_notification_events on public.learner_requests;
create trigger learner_request_notification_events
after insert or update of status on public.learner_requests
for each row execute function private.queue_learner_request_notifications();

create or replace function private.queue_lesson_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  learner_name text := private.profile_display_name(new.learner_id);
  instructor_name text := private.profile_display_name(new.instructor_id);
  lesson_time text := to_char(new.scheduled_at at time zone 'America/Toronto', 'Mon DD at HH12:MI AM');
begin
  if new.learner_id is null then
    return new;
  end if;

  if tg_op = 'INSERT' then
    perform private.enqueue_notification(
      'lesson.booked', new.learner_id, new.instructor_id, 'lesson', new.id,
      'Lesson booked', instructor_name || ' booked your lesson for ' || lesson_time || '.',
      jsonb_build_object('route', '/lessons', 'lessonId', new.id),
      'high', 'lesson-booked-learner:' || new.id::text
    );
    perform private.enqueue_notification(
      'lesson.booked', new.instructor_id, new.learner_id, 'lesson', new.id,
      'Lesson booked', 'Lesson with ' || learner_name || ' is booked for ' || lesson_time || '.',
      jsonb_build_object('route', '/instructor/bookings', 'lessonId', new.id),
      'normal', 'lesson-booked-instructor:' || new.id::text
    );
  elsif tg_op = 'UPDATE' then
    if new.scheduled_at is distinct from old.scheduled_at
      or new.start_time is distinct from old.start_time
      or new.end_time is distinct from old.end_time then
      perform private.enqueue_notification(
        'lesson.rescheduled', new.learner_id, new.instructor_id, 'lesson', new.id,
        'Lesson rescheduled', 'Your lesson is now scheduled for ' || lesson_time || '.',
        jsonb_build_object('route', '/lessons', 'lessonId', new.id),
        'high', 'lesson-rescheduled-learner:' || new.id::text || ':' || extract(epoch from new.updated_at)::bigint::text
      );
      perform private.enqueue_notification(
        'lesson.rescheduled', new.instructor_id, new.learner_id, 'lesson', new.id,
        'Lesson rescheduled', 'Lesson with ' || learner_name || ' is now ' || lesson_time || '.',
        jsonb_build_object('route', '/instructor/bookings', 'lessonId', new.id),
        'high', 'lesson-rescheduled-instructor:' || new.id::text || ':' || extract(epoch from new.updated_at)::bigint::text
      );
    end if;

    if new.status is distinct from old.status then
      if new.status = 'cancelled' then
        perform private.enqueue_notification(
          'lesson.cancelled', new.learner_id, new.instructor_id, 'lesson', new.id,
          'Lesson cancelled', 'Your lesson on ' || lesson_time || ' was cancelled.',
          jsonb_build_object('route', '/lessons', 'lessonId', new.id),
          'high', 'lesson-cancelled-learner:' || new.id::text
        );
        perform private.enqueue_notification(
          'lesson.cancelled', new.instructor_id, new.learner_id, 'lesson', new.id,
          'Lesson cancelled', 'The lesson with ' || learner_name || ' was cancelled.',
          jsonb_build_object('route', '/instructor/bookings', 'lessonId', new.id),
          'high', 'lesson-cancelled-instructor:' || new.id::text
        );
      elsif new.status in ('completed', 'ended') then
        perform private.enqueue_notification(
          'lesson.review.requested', new.learner_id, new.instructor_id, 'lesson', new.id,
          'How was your lesson?', 'Rate your lesson with ' || instructor_name || '.',
          jsonb_build_object('route', '/lessons', 'lessonId', new.id),
          'normal', 'lesson-review-learner:' || new.id::text
        );
        perform private.enqueue_notification(
          'lesson.review.requested', new.instructor_id, new.learner_id, 'lesson', new.id,
          'How was your lesson?', 'Rate your lesson with ' || learner_name || '.',
          jsonb_build_object('route', '/instructor/bookings', 'lessonId', new.id),
          'normal', 'lesson-review-instructor:' || new.id::text
        );
      end if;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists lesson_notification_events on public.lessons;
create trigger lesson_notification_events
after insert or update of status, scheduled_at, start_time, end_time on public.lessons
for each row execute function private.queue_lesson_notifications();

create or replace function private.queue_lesson_reminders()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  queued_count integer := 0;
  lesson_row record;
  reminder_key text;
  reminder_title text;
  reminder_body text;
begin
  for lesson_row in
    select l.*,
      private.profile_display_name(l.learner_id) as learner_name,
      private.profile_display_name(l.instructor_id) as instructor_name
    from public.lessons l
    where l.status = 'scheduled'
      and l.learner_id is not null
      and (
        l.scheduled_at between now() + interval '55 minutes' and now() + interval '65 minutes'
        or l.scheduled_at between now() + interval '23 hours 55 minutes' and now() + interval '24 hours 5 minutes'
      )
  loop
    if lesson_row.scheduled_at < now() + interval '2 hours' then
      reminder_key := '1h';
      reminder_title := 'Lesson in 1 hour';
    else
      reminder_key := '24h';
      reminder_title := 'Lesson tomorrow';
    end if;

    reminder_body := 'Your Drive Tutor lesson starts ' ||
      to_char(lesson_row.scheduled_at at time zone 'America/Toronto', 'Mon DD at HH12:MI AM') || '.';

    perform private.enqueue_notification(
      'lesson.reminder.' || reminder_key, lesson_row.learner_id, lesson_row.instructor_id,
      'lesson', lesson_row.id, reminder_title, reminder_body,
      jsonb_build_object('route', '/lessons', 'lessonId', lesson_row.id),
      'high', 'lesson-reminder-' || reminder_key || '-learner:' || lesson_row.id::text
    );
    perform private.enqueue_notification(
      'lesson.reminder.' || reminder_key, lesson_row.instructor_id, lesson_row.learner_id,
      'lesson', lesson_row.id, reminder_title,
      'Lesson with ' || lesson_row.learner_name || ' starts ' ||
        to_char(lesson_row.scheduled_at at time zone 'America/Toronto', 'Mon DD at HH12:MI AM') || '.',
      jsonb_build_object('route', '/instructor/bookings', 'lessonId', lesson_row.id),
      'high', 'lesson-reminder-' || reminder_key || '-instructor:' || lesson_row.id::text
    );
    queued_count := queued_count + 2;
  end loop;
  return queued_count;
end;
$$;

revoke all on function private.profile_display_name(uuid) from public;
revoke all on function private.enqueue_notification(text, uuid, uuid, text, uuid, text, text, jsonb, text, text, timestamptz) from public;
revoke all on function private.queue_lesson_reminders() from public;

create or replace function public.queue_due_lesson_reminders()
returns integer
language sql
security definer
set search_path = public
as $$
  select private.queue_lesson_reminders();
$$;

revoke all on function public.queue_due_lesson_reminders() from public;
revoke all on function public.queue_due_lesson_reminders() from anon;
revoke all on function public.queue_due_lesson_reminders() from authenticated;
grant execute on function public.queue_due_lesson_reminders() to service_role;
