alter table public.instructor_profiles
  add column if not exists instructor_license_expires_at timestamptz,
  add column if not exists insurance_document_expires_at timestamptz,
  add column if not exists municipal_license_expires_at timestamptz;

create index if not exists instructor_profiles_license_expiry_idx
  on public.instructor_profiles (instructor_license_expires_at);

create index if not exists instructor_profiles_insurance_expiry_idx
  on public.instructor_profiles (insurance_document_expires_at);

