alter table public.profiles
  add column if not exists guardian_identity_license_path text,
  add column if not exists guardian_identity_selfie_path text,
  add column if not exists guardian_consent_submitted_at timestamptz;

create index if not exists profiles_guardian_consent_submitted_at_idx
  on public.profiles (guardian_consent_submitted_at);
