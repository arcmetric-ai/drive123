# Drive Tutor Platform Migration Plan

## Direction

Learners continue to sign up and use Drive Tutor in the mobile app.
Instructors apply, upload credentials, activate billing, and manage account-level tasks on the website.

Both surfaces use the same Supabase project, users, profiles, storage buckets, billing tables, and Edge Functions.

## Mobile App Responsibilities

- Learner signup and onboarding.
- Learner identity/licence verification.
- Instructor login for approved and active instructors.
- Instructor dashboard, requests, availability, lessons, roster, and profile tools.
- Billing entitlement checks before instructor operational access.
- In-app account deletion request entry point for every signed-in user.
- Website handoff for instructor application, activation, billing, and account-level support.

## Website Responsibilities

- Instructor application entry point.
- Instructor login using the same Supabase Auth project.
- Instructor questionnaire.
- Instructor credential uploads to Supabase private storage.
- Consent capture for terms, privacy, data processing, and instructor agreement versions.
- Admin-review status page.
- Instructor activation and reactivation via Stripe Checkout.
- Billing management and support.
- Public legal, privacy, support, and account deletion pages.

## Supabase Responsibilities

- Shared auth users across app and website.
- Shared profile and role tables.
- Private verification and instructor credential buckets.
- Document audit records with hashes, review metadata, retention, and legal-hold fields.
- Stripe pass plan tables and entitlement tables.
- Edge Functions for checkout, webhook fulfillment, admin review, support, and account deletion requests.
- RLS gates for instructor operational tables based on active billing.

## First Implementation Tasks

- Add website routes:
  - `/instructor/apply`
  - `/instructor/activate`
- Update website instructor CTAs to use those routes instead of Google Forms.
- Update mobile role selection so new instructors are sent to the website application path.
- Keep native learner signup unchanged.
- Keep existing in-app instructor billing screen temporarily until website activation is wired and tested.

## Later Tasks

- Build Supabase Auth into the website.
- Replace mock instructor portal pages with live Supabase data.
- Wire website activation to `create-instructor-checkout-session`.
- Add Stripe success/cancel pages and Universal Links/App Links.
- Add `account_deletion_requests` and in-app deletion request UI.
- Harden verification storage policies and add document audit records.
- Add guardian consent flow only after final legal/product decision.
