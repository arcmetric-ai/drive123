-- Preserve 15/30/45 minute lesson durations instead of forcing full-hour values.
alter table public.lessons
  alter column duration_hours type numeric(5,2)
  using duration_hours::numeric(5,2);

-- Learners should still be notified when an instructor books a lesson.
-- Instructors should not receive one push for every lesson they just scheduled.
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

revoke all on function private.queue_lesson_notifications() from public;
revoke all on function private.queue_lesson_notifications() from anon;
revoke all on function private.queue_lesson_notifications() from authenticated;
