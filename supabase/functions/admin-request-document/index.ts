import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

import { requireAdmin } from '../_shared/admin.ts';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { queueNotificationEvent } from '../_shared/notifications.ts';

const documentLabels: Record<string, string> = {
  identity_license: 'government ID or learner licence',
  identity_selfie: 'verification selfie',
  guardian_identity_license: 'guardian government ID',
  guardian_identity_selfie: 'guardian verification selfie',
  instructor_license: 'instructor licence',
  insurance_document: '6D insurance document',
  background_check: 'criminal background check',
  municipal_license: 'municipal licence',
};

const allowedByReviewType: Record<string, Set<string>> = {
  identity_verification: new Set([
    'identity_license',
    'identity_selfie',
    'guardian_identity_license',
    'guardian_identity_selfie',
  ]),
  instructor_credentials: new Set([
    'instructor_license',
    'insurance_document',
    'background_check',
    'municipal_license',
  ]),
};

serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405);
  }

  try {
    const auth = await requireAdmin(request);
    if ('error' in auth) return auth.error;

    const payload = await request.json();
    const profileId = String(payload.profileId ?? '').trim();
    const reviewType = String(payload.reviewType ?? '').trim();
    const documentType = String(payload.documentType ?? '').trim();
    const adminMessage = String(payload.message ?? '').trim();

    if (!profileId || !reviewType || !documentType) {
      return jsonResponse(
        { error: 'profileId, reviewType, and documentType are required.' },
        400,
      );
    }
    if (!allowedByReviewType[reviewType]?.has(documentType)) {
      return jsonResponse({ error: 'Unsupported document request.' }, 400);
    }
    if (adminMessage.length > 1000) {
      return jsonResponse({ error: 'Message must be 1,000 characters or fewer.' }, 400);
    }

    const { admin, adminUser } = auth;
    const { data: profile, error: profileError } = await admin
      .from('profiles')
      .select('id, email, role')
      .eq('id', profileId)
      .maybeSingle();
    if (profileError != null) return jsonResponse({ error: profileError.message }, 400);
    if (profile == null) return jsonResponse({ error: 'Profile not found.' }, 404);

    const { data: existing, error: existingError } = await admin
      .from('verification_document_requests')
      .select('id')
      .eq('profile_id', profileId)
      .eq('document_type', documentType)
      .eq('status', 'requested')
      .maybeSingle();
    if (existingError != null) {
      return jsonResponse({ error: existingError.message }, 400);
    }

    let requestId = String(existing?.id ?? '');
    if (requestId) {
      const { error } = await admin
        .from('verification_document_requests')
        .update({
          requested_by: adminUser.user_id,
          review_type: reviewType,
          admin_message: adminMessage || null,
          updated_at: new Date().toISOString(),
        })
        .eq('id', requestId);
      if (error != null) return jsonResponse({ error: error.message }, 400);
    } else {
      const { data, error } = await admin
        .from('verification_document_requests')
        .insert({
          profile_id: profileId,
          requested_by: adminUser.user_id,
          review_type: reviewType,
          document_type: documentType,
          admin_message: adminMessage || null,
        })
        .select('id')
        .single();
      if (error != null) return jsonResponse({ error: error.message }, 400);
      requestId = String(data.id);
    }

    const documentLabel = documentLabels[documentType];
    const title = `Action needed: Upload ${documentLabel}`;
    const body = adminMessage ||
      `Drive Tutor needs your ${documentLabel}. Open the app and upload it to continue your review.`;
    const screen = reviewType === 'instructor_credentials'
      ? 'instructor_credentials'
      : 'verification_status';

    await queueNotificationEvent(admin, {
      recipientProfileId: profileId,
      actorProfileId: String(adminUser.user_id),
      eventKey: 'verification.document.requested',
      title,
      body,
      channels: ['fcm', 'email'],
      priority: 'high',
      entityType: 'verification_document_request',
      entityId: requestId,
      dedupeKey: `document-request:${requestId}:${Date.now()}`,
      data: {
        screen,
        review_type: reviewType,
        document_type: documentType,
        document_name: documentLabel,
        email: { subject: title, text: body },
      },
    });

    return jsonResponse({ success: true, requestId, documentType });
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'Unexpected error.' },
      500,
    );
  }
});
