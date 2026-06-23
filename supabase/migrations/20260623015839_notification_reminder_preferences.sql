alter table public.notification_preferences
  add column if not exists lesson_reminders_enabled boolean not null default true;

comment on column public.notification_preferences.lesson_reminders_enabled is
  'Controls lesson reminder notifications separately from booking and schedule update notifications.';
