-- Backfill instructors approved through the admin credentials queue before
-- instructor approval also finalized the profile identity gate.
update public.profiles as profile
set
  verification_status = 'approved',
  verification_review_started_at = coalesce(
    profile.verification_review_started_at,
    instructor.credentials_review_started_at,
    instructor.credentials_approved_at,
    now()
  ),
  verification_approved_at = coalesce(
    profile.verification_approved_at,
    instructor.credentials_approved_at,
    now()
  ),
  verification_rejected_at = null,
  verification_rejection_reason = null,
  verification_review_notes = coalesce(
    nullif(profile.verification_review_notes, ''),
    instructor.credentials_review_notes
  ),
  verification_reviewed_by = coalesce(
    profile.verification_reviewed_by,
    instructor.credentials_reviewed_by
  ),
  is_verified = true
from public.instructor_profiles as instructor
where instructor.profile_id = profile.id
  and profile.role = 'instructor'
  and instructor.credentials_status = 'approved'
  and profile.identity_license_path is not null
  and btrim(profile.identity_license_path) <> ''
  and profile.identity_selfie_path is not null
  and btrim(profile.identity_selfie_path) <> ''
  and (
    profile.verification_status is distinct from 'approved'
    or coalesce(profile.is_verified, false) is not true
  );
