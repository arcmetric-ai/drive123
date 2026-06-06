import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

import { requireAdmin } from '../_shared/admin.ts';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';

serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405);
  }

  try {
    const auth = await requireAdmin(request);
    if ('error' in auth) {
      return auth.error;
    }

    const { admin, adminUser } = auth;
    const payload = await request.json();

    const reviewType = String(payload.reviewType ?? '').trim();
    const userId = String(payload.userId ?? '').trim();
    const status = String(payload.status ?? '').trim().toLowerCase();
    const rejectionReason = String(payload.rejectionReason ?? '').trim();
    const reviewNotes = String(payload.reviewNotes ?? '').trim();

    if (reviewType.length === 0 || userId.length === 0 || status.length === 0) {
      return jsonResponse(
        { error: 'Missing reviewType, userId, or status.' },
        400,
      );
    }

    if (status !== 'approved' && status !== 'rejected') {
      return jsonResponse(
        { error: 'Status must be approved or rejected.' },
        400,
      );
    }

    if (status === 'rejected' && rejectionReason.length === 0) {
      return jsonResponse(
        { error: 'Rejection reason is required when rejecting a review.' },
        400,
      );
    }

    const nowIso = new Date().toISOString();

    if (reviewType === 'identity_verification') {
      const { data: profile, error: profileError } = await admin
        .from('profiles')
        .select('id, role, verification_status, verification_review_started_at')
        .eq('id', userId)
        .maybeSingle();

      if (profileError != null) {
        return jsonResponse({ error: profileError.message }, 400);
      }

      if (profile == null) {
        return jsonResponse({ error: 'Profile not found.' }, 404);
      }

      const role = String(profile.role ?? '').trim().toLowerCase();
      const isLearner = role === 'learner';

      const update: Record<string, unknown> = {
        verification_status: status,
        verification_reviewed_by: adminUser.user_id,
        verification_review_started_at:
          profile.verification_review_started_at ?? nowIso,
        verification_review_notes:
          reviewNotes.length === 0 ? null : reviewNotes,
        is_verified: status === 'approved' && isLearner,
      };

      if (status === 'approved') {
        update.verification_approved_at = nowIso;
        update.verification_rejected_at = null;
        update.verification_rejection_reason = null;
      } else {
        update.verification_approved_at = null;
        update.verification_rejected_at = nowIso;
        update.verification_rejection_reason = rejectionReason;
      }

      const { error: updateError } = await admin
        .from('profiles')
        .update(update)
        .eq('id', userId);

      if (updateError != null) {
        return jsonResponse({ error: updateError.message }, 400);
      }

      return jsonResponse({
        success: true,
        reviewType,
        userId,
        status,
      });
    }

    if (reviewType === 'instructor_credentials') {
      const { data: instructorProfile, error: instructorError } = await admin
        .from('instructor_profiles')
        .select(
          `
            profile_id,
            credentials_status,
            credentials_review_started_at,
            profile:profiles!instructor_profiles_profile_id_fkey(
              id,
              role,
              verification_status
            )
          `,
        )
        .eq('profile_id', userId)
        .maybeSingle();

      if (instructorError != null) {
        return jsonResponse({ error: instructorError.message }, 400);
      }

      if (instructorProfile == null) {
        return jsonResponse({ error: 'Instructor profile not found.' }, 404);
      }

      const update: Record<string, unknown> = {
        credentials_status: status,
        credentials_reviewed_by: adminUser.user_id,
        credentials_review_started_at:
          instructorProfile.credentials_review_started_at ?? nowIso,
        credentials_review_notes:
          reviewNotes.length === 0 ? null : reviewNotes,
      };

      if (status === 'approved') {
        update.credentials_approved_at = nowIso;
        update.credentials_rejected_at = null;
        update.credentials_rejection_reason = null;
      } else {
        update.credentials_approved_at = null;
        update.credentials_rejected_at = nowIso;
        update.credentials_rejection_reason = rejectionReason;
      }

      const { error: updateError } = await admin
        .from('instructor_profiles')
        .update(update)
        .eq('profile_id', userId);

      if (updateError != null) {
        return jsonResponse({ error: updateError.message }, 400);
      }

      const profile =
        (instructorProfile.profile as Record<string, unknown> | null) ?? {};
      const identityApproved =
        String(profile.verification_status ?? '').trim().toLowerCase() ===
        'approved';

      const { error: profileUpdateError } = await admin
        .from('profiles')
        .update({
          is_verified: status === 'approved' && identityApproved,
        })
        .eq('id', userId);

      if (profileUpdateError != null) {
        return jsonResponse({ error: profileUpdateError.message }, 400);
      }

      return jsonResponse({
        success: true,
        reviewType,
        userId,
        status,
      });
    }

    return jsonResponse({ error: 'Unsupported reviewType.' }, 400);
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'Unexpected error.' },
      500,
    );
  }
});
