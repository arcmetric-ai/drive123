# Drive Tutor Release Action Split

## Owner tasks outside the repo

- Confirm the permanent production identifier before app records are created.
  Recommended default: `ca.drivetutor.app`.
- Create or confirm public legal URLs:
  - privacy policy
  - terms of service
  - support/contact
  - account and data deletion
- Apple Developer/App Store Connect:
  - create the Bundle ID after identifier confirmation
  - enable required capabilities for app links
  - create the App Store Connect app record
  - complete App Privacy, age rating, export compliance, review contact, and TestFlight tester setup
- Google Play Console:
  - create the app after package identifier confirmation
  - enable Play App Signing
  - complete Data Safety, content rating, app access, target audience, privacy policy, and internal/closed testing setup
- Supabase dashboard:
  - confirm the production project to use
  - confirm redirect allow-list entries for production app links
  - confirm Edge Function secrets are present
  - add at least one admin account to `public.admin_users`

## Agent/code tasks

- Replace default iOS/Android app identifiers after owner confirms the final identifier.
- Configure Android release signing to use an untracked upload keystore.
- Add iOS and Android app-link/deep-link config after the identifier and public domain files are ready.
- Make Supabase schema reproducible from migrations, including base tables, RLS policies, storage buckets, and admin review tables.
- Keep `.env` out of bundled app assets and use `--dart-define` for public Supabase client values.
- Fix smoke tests and reduce analyzer warnings that affect release confidence.
- Produce TestFlight archive and signed Android App Bundle once signing and identifiers are ready.

## Current first-pass status

- `.env` is no longer bundled as a Flutter asset.
- App config now prefers `--dart-define=SUPABASE_URL` and `--dart-define=SUPABASE_ANON_KEY`.
- Analyzer excludes generated/build folders and the bundled Flutter SDK tree.
- The smoke test now checks the current splash title, `DRIVE TUTOR`.
