# Drive Tutor Store Submission Inputs

## Identifier decision

Confirm before creating app records:

- iOS Bundle ID: recommended `ca.drivetutor.app`
- Android package name: recommended `ca.drivetutor.app`

These identifiers are hard to change after store records/uploads exist.

## Public URLs to publish first

- Privacy policy
- Terms of service
- Support/contact
- Account and data deletion instructions

Use the same canonical domain everywhere, preferably `https://www.drivetutor.ca`.

## Apple App Store Connect inputs

- App name: `Drive Tutor`
- Subtitle
- Promotional text
- Description
- Keywords
- Support URL
- Marketing URL, if available
- Privacy policy URL
- Copyright owner
- Review contact name, phone, and email
- Demo account credentials for review, if login is required
- App Privacy answers for:
  - contact info
  - identity verification images/documents
  - learner/instructor profile data
  - lesson and scheduling data
  - pickup/location preferences
  - uploaded profile/vehicle/document images
  - diagnostics, if added later

## Google Play Console inputs

- App name: `Drive Tutor`
- Short description
- Full description
- App category
- Contact email
- Privacy policy URL
- App access instructions and demo credentials, if login is required
- Content rating questionnaire
- Target audience declaration
- Data Safety answers matching the Apple privacy data inventory
- Internal or closed testing track tester list

## Android upload key inputs

Create these locally and do not commit them:

- `android/upload-keystore.jks`
- `android/key.properties`

Use `android/key.properties.example` as the template.

## Build-time config inputs

Release builds should pass public Supabase client config with:

```sh
--dart-define=SUPABASE_URL=...
--dart-define=SUPABASE_ANON_KEY=...
```

Do not bundle `.env` into release assets.
