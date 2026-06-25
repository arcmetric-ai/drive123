create or replace function private.schedule_lesson_reminder_events(
  target_lesson_id uuid,
  target_learner_id uuid,
  target_instructor_id uuid,
  target_scheduled_at timestamptz,
  target_external_learner_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  reminder record;
  lesson_time text;
  learner_name text := coalesce(
    private.profile_display_name(target_learner_id),
    private.external_learner_display_name(target_external_learner_id),
    'your learner'
  );
  instructor_name text := private.profile_display_name(target_instructor_id);
  scheduled_for timestamptz;
  dedupe_suffix text;
begin
  if target_lesson_id is null
    or target_instructor_id is null
    or (target_learner_id is null and target_external_learner_id is null)
    or target_scheduled_at is null
    or target_scheduled_at <= now() then
    return;
  end if;

  lesson_time := to_char(target_scheduled_at at time zone 'America/Toronto', 'Mon DD at HH12:MI AM');
  dedupe_suffix := ':' || target_lesson_id::text || ':' || extract(epoch from target_scheduled_at)::bigint::text;

  for reminder in
    select *
    from (
      values
        ('24h'::text, interval '24 hours', 'Lesson tomorrow'::text),
        ('1h'::text, interval '1 hour', 'Lesson in 1 hour'::text)
    ) as reminders(reminder_key, reminder_offset, reminder_title)
  loop
    scheduled_for := target_scheduled_at - reminder.reminder_offset;

    if scheduled_for <= now() then
      if reminder.reminder_key = '1h' then
        scheduled_for := now();
      else
        continue;
      end if;
    end if;

    if target_learner_id is not null then
      perform private.enqueue_notification(
        'lesson.reminder.' || reminder.reminder_key,
        target_learner_id,
        target_instructor_id,
        'lesson',
        target_lesson_id,
        reminder.reminder_title,
        'Your lesson with ' || coalesce(instructor_name, 'your instructor') || ' starts ' || lesson_time || '.',
        jsonb_build_object(
          'route', '/lessons',
          'lessonId', target_lesson_id,
          'type', 'lesson_reminder',
          'reminderWindow', reminder.reminder_key
        ),
        'high',
        'lesson-reminder-' || reminder.reminder_key || '-learner' || dedupe_suffix,
        scheduled_for
      );
    end if;

    perform private.enqueue_notification(
      'lesson.reminder.' || reminder.reminder_key,
      target_instructor_id,
      target_learner_id,
      'lesson',
      target_lesson_id,
      reminder.reminder_title,
      'Lesson with ' || learner_name || ' starts ' || lesson_time || '.',
      jsonb_build_object(
        'route', '/instructor/bookings',
        'lessonId', target_lesson_id,
        'type', 'lesson_reminder',
        'reminderWindow', reminder.reminder_key
      ),
      'high',
      'lesson-reminder-' || reminder.reminder_key || '-instructor' || dedupe_suffix,
      scheduled_for
    );
  end loop;
end;
$$;

revoke all on function private.schedule_lesson_reminder_events(uuid, uuid, uuid, timestamptz, uuid) from public;
revoke all on function private.schedule_lesson_reminder_events(uuid, uuid, uuid, timestamptz, uuid) from anon;
revoke all on function private.schedule_lesson_reminder_events(uuid, uuid, uuid, timestamptz, uuid) from authenticated;

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
  learner_body text;
  instructor_body text;
begin
  for lesson_row in
    select
      l.*,
      coalesce(
        private.profile_display_name(l.learner_id),
        private.external_learner_display_name(l.external_learner_id),
        'your learner'
      ) as learner_name,
      private.profile_display_name(l.instructor_id) as instructor_name
    from public.lessons l
    where coalesce(l.status, 'scheduled') in ('scheduled', 'booked', 'confirmed')
      and (l.learner_id is not null or l.external_learner_id is not null)
      and l.instructor_id is not null
      and l.scheduled_at > now()
      and (
        l.scheduled_at between now() and now() + interval '75 minutes'
        or l.scheduled_at between now() + interval '23 hours' and now() + interval '25 hours'
      )
  loop
    if lesson_row.scheduled_at < now() + interval '2 hours' then
      reminder_key := '1h';
      reminder_title := 'Lesson in 1 hour';
    else
      reminder_key := '24h';
      reminder_title := 'Lesson tomorrow';
    end if;

    learner_body := 'Your lesson with ' || coalesce(lesson_row.instructor_name, 'your instructor') ||
      ' starts ' ||
      to_char(lesson_row.scheduled_at at time zone 'America/Toronto', 'Mon DD at HH12:MI AM') || '.';

    instructor_body := 'Lesson with ' || coalesce(lesson_row.learner_name, 'your learner') ||
      ' starts ' ||
      to_char(lesson_row.scheduled_at at time zone 'America/Toronto', 'Mon DD at HH12:MI AM') || '.';

    if lesson_row.learner_id is not null and not exists (
      select 1
      from public.notification_events existing
      where existing.entity_type = 'lesson'
        and existing.entity_id = lesson_row.id
        and existing.recipient_profile_id = lesson_row.learner_id
        and existing.event_key = 'lesson.reminder.' || reminder_key
    ) then
      perform private.enqueue_notification(
        'lesson.reminder.' || reminder_key,
        lesson_row.learner_id,
        lesson_row.instructor_id,
        'lesson',
        lesson_row.id,
        reminder_title,
        learner_body,
        jsonb_build_object(
          'route', '/lessons',
          'lessonId', lesson_row.id,
          'type', 'lesson_reminder',
          'reminderWindow', reminder_key
        ),
        'high',
        'lesson-reminder-' || reminder_key || '-learner:' || lesson_row.id::text
      );

      queued_count := queued_count + 1;
    end if;

    if not exists (
      select 1
      from public.notification_events existing
      where existing.entity_type = 'lesson'
        and existing.entity_id = lesson_row.id
        and existing.recipient_profile_id = lesson_row.instructor_id
        and existing.event_key = 'lesson.reminder.' || reminder_key
    ) then
      perform private.enqueue_notification(
        'lesson.reminder.' || reminder_key,
        lesson_row.instructor_id,
        lesson_row.learner_id,
        'lesson',
        lesson_row.id,
        reminder_title,
        instructor_body,
        jsonb_build_object(
          'route', '/instructor/bookings',
          'lessonId', lesson_row.id,
          'type', 'lesson_reminder',
          'reminderWindow', reminder_key
        ),
        'high',
        'lesson-reminder-' || reminder_key || '-instructor:' || lesson_row.id::text
      );

      queued_count := queued_count + 1;
    end if;
  end loop;

  return queued_count;
end;
$$;

revoke all on function private.queue_lesson_reminders() from public;
revoke all on function private.queue_lesson_reminders() from anon;
revoke all on function private.queue_lesson_reminders() from authenticated;

select private.schedule_lesson_reminder_events(
  lesson.id,
  lesson.learner_id,
  lesson.instructor_id,
  lesson.scheduled_at,
  lesson.external_learner_id
)
from public.lessons lesson
where coalesce(lesson.status, 'scheduled') in ('scheduled', 'booked', 'confirmed')
  and lesson.scheduled_at > now()
  and lesson.scheduled_at < now() + interval '75 minutes'
  and lesson.instructor_id is not null
  and (lesson.learner_id is not null or lesson.external_learner_id is not null);
