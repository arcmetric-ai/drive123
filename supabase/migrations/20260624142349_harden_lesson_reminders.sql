-- Make lesson reminders tolerant of slightly early/late queue-worker runs.
-- Dedupe keys still prevent repeated notifications for the same lesson/window.

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
      private.profile_display_name(l.learner_id) as learner_name,
      private.profile_display_name(l.instructor_id) as instructor_name
    from public.lessons l
    where coalesce(l.status, 'scheduled') in ('scheduled', 'booked', 'confirmed')
      and l.learner_id is not null
      and l.instructor_id is not null
      and l.scheduled_at > now()
      and (
        l.scheduled_at between now() + interval '45 minutes' and now() + interval '75 minutes'
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

    queued_count := queued_count + 2;
  end loop;

  return queued_count;
end;
$$;

revoke all on function private.queue_lesson_reminders() from public;
revoke all on function private.queue_lesson_reminders() from anon;
revoke all on function private.queue_lesson_reminders() from authenticated;

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
