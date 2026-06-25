create or replace function public.ensure_notification_preferences_for_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notification_preferences (
    profile_id,
    fcm_enabled,
    email_enabled,
    lesson_updates_enabled,
    lesson_reminders_enabled,
    review_updates_enabled,
    pass_updates_enabled,
    support_updates_enabled,
    marketing_enabled,
    timezone
  )
  values (
    new.id,
    true,
    true,
    true,
    true,
    true,
    true,
    true,
    false,
    'America/Toronto'
  )
  on conflict (profile_id) do nothing;

  return new;
end;
$$;

drop trigger if exists ensure_notification_preferences_after_profile_insert
  on public.profiles;

create trigger ensure_notification_preferences_after_profile_insert
after insert on public.profiles
for each row
execute function public.ensure_notification_preferences_for_profile();

insert into public.notification_preferences (
  profile_id,
  fcm_enabled,
  email_enabled,
  lesson_updates_enabled,
  lesson_reminders_enabled,
  review_updates_enabled,
  pass_updates_enabled,
  support_updates_enabled,
  marketing_enabled,
  timezone
)
select
  profile.id,
  true,
  true,
  true,
  true,
  true,
  true,
  true,
  false,
  'America/Toronto'
from public.profiles profile
left join public.notification_preferences prefs
  on prefs.profile_id = profile.id
where prefs.profile_id is null
  and profile.id is not null
on conflict (profile_id) do nothing;
