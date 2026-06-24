# Drive Tutor Handover - 2026-06-24

## Repositories

- Mobile app: `/Users/abhi/Downloads/drive-t-app`
  - GitHub: `https://github.com/DriveTutor/mob-app-dt.git`
  - Branch: `main`
- Website: `/Users/abhi/Downloads/drive-t-app/Website-main`
  - GitHub: `https://github.com/DriveTutor/Website.git`
  - Branch: `main`
- Admin dashboard: `/Users/abhi/Downloads/dt-admin-dashboard`
  - GitHub: `https://github.com/DriveTutor/ad-dash-main.git`
  - Branch: `main`

## Current Focus

The current priority is making sure learners and instructors receive lesson reminder push notifications, then producing fresh TestFlight and Google Play internal testing builds.

## Reminder Notification Flow

Reminder notifications now depend on three pieces:

1. Database queues due reminder events.
2. `process-notification-queue` calls the database queue function and then dispatches queued events.
3. A scheduler calls `process-notification-queue` regularly.

### Changes Made

- Added migration:
  - `/Users/abhi/Downloads/drive-t-app/supabase/migrations/20260624142349_harden_lesson_reminders.sql`
- Updated Edge Function:
  - `/Users/abhi/Downloads/drive-t-app/supabase/functions/process-notification-queue/index.ts`
- Updated Supabase function config:
  - `/Users/abhi/Downloads/drive-t-app/supabase/config.toml`

The new reminder SQL queues reminders for both sides of a lesson:

- Learner recipient:
  - Event key: `lesson.reminder.1h` or `lesson.reminder.24h`
  - Route data: `/lessons`
- Instructor recipient:
  - Event key: `lesson.reminder.1h` or `lesson.reminder.24h`
  - Route data: `/instructor/bookings`

It queues reminders for lessons with status `scheduled`, `booked`, or `confirmed`, when:

- 1-hour reminder window: lesson starts between 45 and 75 minutes from now.
- 24-hour reminder window: lesson starts between 23 and 25 hours from now.

Separate dedupe keys are used for learner and instructor, so one recipient cannot suppress the other:

- `lesson-reminder-1h-learner:<lesson_id>`
- `lesson-reminder-1h-instructor:<lesson_id>`
- `lesson-reminder-24h-learner:<lesson_id>`
- `lesson-reminder-24h-instructor:<lesson_id>`

### Backend Steps Still Required

Even if migrations and functions were deployed earlier today, this new migration and config/function change must be deployed after this handover:

```bash
cd /Users/abhi/Downloads/drive-t-app
supabase db push
supabase functions deploy process-notification-queue
supabase functions deploy send-notification-event
```

If admin review changes are part of the build being tested, also deploy:

```bash
supabase functions deploy admin-update-review-status
```

### Required Scheduler

There is no repo-level scheduler file for `process-notification-queue`. Lesson reminders will not fire unless Supabase cron or an external scheduler calls it.

Recommended schedule: every 5 minutes.

Request:

```bash
curl -X POST \
  "https://<SUPABASE_PROJECT_REF>.supabase.co/functions/v1/process-notification-queue" \
  -H "x-cron-secret: <CRON_SECRET>" \
  -H "Content-Type: application/json"
```

The function now has `verify_jwt = false` in `supabase/config.toml`, but it still requires `x-cron-secret`. It uses the service role key only inside the function.

### Required Supabase Secrets

Confirm these are set in the Supabase Edge Function environment:

- `CRON_SECRET`
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- Firebase service account:
  - either `FIREBASE_SERVICE_ACCOUNT_JSON`
  - or all of `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`
- Resend email:
  - `RESEND_API_KEY`
  - `RESEND_FROM_EMAIL`
  - optional `RESEND_REPLY_TO_EMAIL`

### Reminder Preferences

The notification centre migration already added:

- `notification_preferences.lesson_reminders_enabled boolean not null default true`

`send-notification-event` maps `lesson.reminder.*` events to this preference. If a user disables lesson reminders, queued reminder events are cancelled instead of sent.

## Verification So Far

- `git diff --check` passed in the mobile app repo.
- Reminder SQL was reviewed locally.
- `process-notification-queue` now reports `queuedReminders` in its JSON response.
- `send-notification-event` already dispatches FCM and email where configured.
- `deno check` could not be run locally because `deno` is not installed.

## Builds

Use Dart defines. Do not rely on directly loading `.env` at runtime for release builds.

Recommended next build number: use a number higher than the latest uploaded build. Earlier TestFlight used `1.0.0 (1)` and later local builds used build `2`, so use `3` unless App Store Connect/Google Play already consumed it.

```bash
cd /Users/abhi/Downloads/drive-t-app
flutter clean
flutter pub get
flutter build appbundle --release --build-name 1.0.0 --build-number 3 --dart-define-from-file=.env
flutter build ipa --release --build-name 1.0.0 --build-number 3 --dart-define-from-file=.env
```

Expected artifacts:

- Android AAB:
  - `/Users/abhi/Downloads/drive-t-app/build/app/outputs/bundle/release/app-release.aab`
- iOS IPA:
  - `/Users/abhi/Downloads/drive-t-app/build/ios/ipa/Drive Tutor.ipa`

### Latest Local Build Result

After the notification reminder hardening commit, local release builds succeeded with:

- Version: `1.0.0`
- Build number: `3`
- Android AAB:
  - `/Users/abhi/Downloads/drive-t-app/build/app/outputs/bundle/release/app-release.aab`
- iOS IPA:
  - `/Users/abhi/Downloads/drive-t-app/build/ios/ipa/Drive Tutor.ipa`

The iOS build emitted a non-blocking warning that the launch image is still the default placeholder.

## Known Testing Notes

- Test reminder flow by creating a lesson 50-65 minutes in the future, then manually calling `process-notification-queue`.
- The response should show `queuedReminders` greater than `0` the first time.
- Verify both learner and instructor profiles have active `device_tokens` rows.
- Verify both profiles have `lesson_reminders_enabled = true`.
- Repeated calls should not duplicate reminders because dedupe keys are per lesson, window, and recipient.

## Recent Mobile Areas Touched

- Learner/guardian onboarding and password creation flow.
- Guardian role and admin review handling.
- Document resubmission screen after admin requests a corrected document.
- Android launcher icon padding.
- Notification centre/preferences.
- Push token registration and notification dispatch handling.
- Edit profile and onboarding form validation.

## Recent Supabase Areas Touched

- Guardian role migration:
  - `/Users/abhi/Downloads/drive-t-app/supabase/migrations/20260624033332_allow_guardian_profile_role.sql`
- Signup/private schema trigger permissions:
  - `/Users/abhi/Downloads/drive-t-app/supabase/migrations/20260623154100_fix_signup_private_schema_trigger_permissions.sql`
- Reminder hardening:
  - `/Users/abhi/Downloads/drive-t-app/supabase/migrations/20260624142349_harden_lesson_reminders.sql`
- Admin review status function:
  - `/Users/abhi/Downloads/drive-t-app/supabase/functions/admin-update-review-status/index.ts`
- Notification event sender:
  - `/Users/abhi/Downloads/drive-t-app/supabase/functions/send-notification-event/index.ts`
- Notification queue processor:
  - `/Users/abhi/Downloads/drive-t-app/supabase/functions/process-notification-queue/index.ts`

## Open Risks

- Reminder delivery depends on the scheduler being active. Code alone is not enough.
- The new reminder migration must be applied after this handover if it has not already been applied.
- Edge Functions must be redeployed after the latest code/config changes.
- Local Deno validation was not possible.
- Android launcher icon was reduced/padded, but final visual confirmation should be done on a tester device after the new AAB is installed.
