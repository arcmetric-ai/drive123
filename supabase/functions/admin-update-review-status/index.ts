import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { type SupabaseClient } from 'npm:@supabase/supabase-js@2';

import { requireAdmin } from '../_shared/admin.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const requireDocumentScan =
  String(Deno.env.get('REQUIRE_DOCUMENT_SCAN') ?? 'false').toLowerCase() !==
  'false';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const defaultMunicipalLicenseRequiredCities = [
  'toronto',
  'ottawa',
  'mississauga',
  'brampton',
  'vaughan',
  'markham',
  'barrie',
  'guelph',
  'oshawa',
];
const municipalLicenseNotRequiredCities = new Set([
  'etobicoke',
  'downsview',
  'port union',
]);

type NotificationChannel = 'fcm' | 'email';

type QueueNotificationInput = {
  recipientProfileId: string;
  actorProfileId?: string | null;
  eventKey: string;
  title: string;
  body: string;
  channels?: NotificationChannel[];
  priority?: 'low' | 'normal' | 'high';
  entityType?: string | null;
  entityId?: string | null;
  dedupeKey?: string | null;
  data?: Record<string, unknown>;
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

function cleanString(value: unknown) {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function parseLocations(value: unknown) {
  const locations = new Set<string>();

  const visit = (entry: unknown) => {
    if (!entry) return;
    if (typeof entry === 'string') {
      const cleaned = entry.trim();
      if (cleaned) locations.add(cleaned);
      return;
    }
    if (Array.isArray(entry)) {
      entry.forEach(visit);
      return;
    }
    if (typeof entry === 'object') {
      const map = entry as Record<string, unknown>;
      [
        'city',
        'label',
        'name',
        'area',
        'areaName',
        'address',
        'municipality',
        'location',
        'service_area',
        'serviceArea',
        'service_area_city',
        'serviceAreaCity',
      ].forEach((key) => visit(map[key]));
    }
  };

  visit(value);
  return Array.from(locations);
}

function mergeLocations(...values: unknown[]) {
  const seen = new Set<string>();
  const locations: string[] = [];
  values.flatMap(parseLocations).forEach((location) => {
    const key = location.toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    locations.push(location);
  });
  return locations;
}

function configuredMunicipalCities() {
  const configured = (Deno.env.get('MUNICIPAL_LICENSE_REQUIRED_CITIES') ?? '')
    .split(',')
    .map((city) => city.trim().toLowerCase())
    .filter((city) => city && !municipalLicenseNotRequiredCities.has(city));
  return configured.length ? configured : defaultMunicipalLicenseRequiredCities;
}

function municipalLicenseRequired(serviceAreas: string[]) {
  const requiredCities = configuredMunicipalCities();
  return serviceAreas.some((area) => {
    const normalized = area.toLowerCase();
    return requiredCities.some((city) => normalized.includes(city));
  });
}

async function queueNotificationEvent(
  admin: SupabaseClient,
  input: QueueNotificationInput,
) {
  let actorProfileId = input.actorProfileId ?? null;
  if (actorProfileId != null) {
    const { data: actorProfile, error: actorProfileError } = await admin
      .from('profiles')
      .select('id')
      .eq('id', actorProfileId)
      .maybeSingle();
    if (actorProfileError != null) {
      throw new Error(actorProfileError.message);
    }
    actorProfileId = actorProfile == null ? null : actorProfileId;
  }

  const { data, error } = await admin
    .from('notification_events')
    .insert({
      event_key: input.eventKey,
      recipient_profile_id: input.recipientProfileId,
      actor_profile_id: actorProfileId,
      entity_type: input.entityType ?? null,
      entity_id: input.entityId ?? null,
      title: input.title,
      body: input.body,
      channels: input.channels ?? ['fcm'],
      priority: input.priority ?? 'normal',
      data: input.data ?? {},
      dedupe_key: input.dedupeKey ?? null,
    })
    .select('id')
    .maybeSingle();

  if (error != null) {
    throw new Error(error.message);
  }

  const eventId = String(data?.id ?? '');
  if (eventId.length > 0) {
    await dispatchNotificationEvent(eventId).catch((error) => {
      console.error(
        error instanceof Error ? error.message : 'Notification dispatch failed.',
      );
    });
  }
}

async function dispatchNotificationEvent(eventId: string) {
  if (!supabaseUrl || !serviceRoleKey) return;

  const response = await fetch(`${supabaseUrl}/functions/v1/send-notification-event`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ eventId }),
  });

  if (!response.ok) {
    const message = await response.text();
    throw new Error(`Notification dispatch failed: ${message}`);
  }
}

function displayName(profile: Record<string, unknown> | null | undefined) {
  const firstName = String(profile?.first_name ?? '').trim();
  const lastName = String(profile?.last_name ?? '').trim();
  const fullName = `${firstName} ${lastName}`.trim();
  return fullName.length > 0 ? fullName : 'Drive Tutor user';
}

async function appendDocumentReviewEvents(
  admin: SupabaseClient,
  userId: string,
  documentTypes: string[],
  status: 'approved' | 'rejected',
  adminUserId: string,
  reviewNotes: string,
  rejectionReason: string,
) {
  const { data: versions, error: versionError } = await admin
    .from('verification_document_versions')
    .select('id, document_type, version_number')
    .eq('owner_user_id', userId)
    .in('document_type', documentTypes)
    .order('version_number', { ascending: false });
  if (versionError != null) throw new Error(versionError.message);

  const latestByType = new Map<string, Record<string, unknown>>();
  for (const version of versions ?? []) {
    const type = String(version.document_type);
    if (!latestByType.has(type)) latestByType.set(type, version);
  }
  if (latestByType.size === 0) {
    throw new Error('No immutable document versions were found for this review.');
  }

  const latestVersions = [...latestByType.values()];
  if (status === 'approved' && requireDocumentScan) {
    const ids = latestVersions.map((version) => String(version.id));
    const { data: scans, error: scanError } = await admin
      .from('verification_document_scan_events')
      .select('document_version_id, status, created_at')
      .in('document_version_id', ids)
      .order('created_at', { ascending: false });
    if (scanError != null) throw new Error(scanError.message);

    const latestScan = new Map<string, string>();
    for (const scan of scans ?? []) {
      const id = String(scan.document_version_id);
      if (!latestScan.has(id)) latestScan.set(id, String(scan.status));
    }
    const unsafe = ids.filter((id) => latestScan.get(id) !== 'clean');
    if (unsafe.length > 0) {
      throw new Error('Every current document must pass malware scanning before approval.');
    }
  }

  const { error: eventError } = await admin
    .from('verification_document_review_events')
    .insert(latestVersions.map((version) => ({
      document_version_id: version.id,
      status,
      reviewed_by: adminUserId,
      notes: reviewNotes.length === 0 ? null : reviewNotes,
      rejection_reason: status === 'rejected' ? rejectionReason : null,
    })));
  if (eventError != null) throw new Error(eventError.message);
}

async function assertCurrentDocumentsScanned(
  admin: SupabaseClient,
  userId: string,
  documentTypes: string[],
  requiredTypes: string[],
) {
  const { data: versions, error: versionError } = await admin
    .from('verification_document_versions')
    .select('id, document_type, version_number')
    .eq('owner_user_id', userId)
    .in('document_type', documentTypes)
    .order('version_number', { ascending: false });
  if (versionError != null) throw new Error(versionError.message);

  const latestByType = new Map<string, Record<string, unknown>>();
  for (const version of versions ?? []) {
    const type = String(version.document_type);
    if (!latestByType.has(type)) latestByType.set(type, version);
  }
  const missing = requiredTypes.filter((type) => !latestByType.has(type));
  if (missing.length > 0) {
    throw new Error(`Required document versions are missing: ${missing.join(', ')}.`);
  }

  const ids = [...latestByType.values()].map((version) => String(version.id));
  const { data: scans, error: scanError } = await admin
    .from('verification_document_scan_events')
    .select('document_version_id, status, created_at')
    .in('document_version_id', ids)
    .order('created_at', { ascending: false });
  if (scanError != null) throw new Error(scanError.message);

  const latestScan = new Map<string, string>();
  for (const scan of scans ?? []) {
    const id = String(scan.document_version_id);
    if (!latestScan.has(id)) latestScan.set(id, String(scan.status));
  }
  if (ids.some((id) => latestScan.get(id) !== 'clean')) {
    throw new Error('Every current document must pass malware scanning before approval.');
  }
}

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
        .select(
          'id, role, first_name, last_name, verification_status, verification_review_started_at',
        )
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
      const isGuardian = role === 'guardian';
      let isGuardianReview = isGuardian;

      if (isLearner || isGuardian) {
        const { data: learnerProfile, error: learnerProfileError } = await admin
          .from('learner_profiles')
          .select('account_type, ward_first_name, ward_last_name')
          .eq('profile_id', userId)
          .maybeSingle();

        if (learnerProfileError != null) {
          return jsonResponse({ error: learnerProfileError.message }, 400);
        }

        isGuardianReview =
          isGuardianReview ||
          String(learnerProfile?.account_type ?? '').trim().toLowerCase() ===
            'guardian';
      }

      const isLearnerLikeReview = isLearner || isGuardianReview;

      if (status === 'approved' && requireDocumentScan) {
        await assertCurrentDocumentsScanned(
          admin,
          userId,
          isGuardianReview
            ? ['guardian_identity_license']
            : ['identity_license'],
          isGuardianReview
            ? ['guardian_identity_license']
            : ['identity_license'],
        );
      }

      const update: Record<string, unknown> = {
        verification_status: status,
        verification_reviewed_by: adminUser.user_id,
        verification_review_started_at:
          profile.verification_review_started_at ?? nowIso,
        verification_review_notes:
          reviewNotes.length === 0 ? null : reviewNotes,
        is_verified: status === 'approved' && isLearnerLikeReview,
      };

      if (status === 'approved') {
        update.verification_approved_at = nowIso;
        update.verification_rejected_at = null;
        update.verification_rejection_reason = null;
        if (isLearnerLikeReview) {
          update.onboarding_stage = 'questionnaire_complete';
        }
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

      await appendDocumentReviewEvents(
        admin,
        userId,
        isGuardianReview
          ? ['guardian_identity_license']
          : ['identity_license'],
        status,
        String(adminUser.user_id),
        reviewNotes,
        rejectionReason,
      );

      const reviewEventKey = isGuardianReview
        ? status === 'approved'
          ? 'guardian.review.approved'
          : 'guardian.review.changes_required'
        : status === 'approved'
        ? 'learner.review.approved'
        : 'learner.review.changes_required';
      const reviewTitle = status === 'approved'
        ? isGuardianReview
          ? 'Guardian verification approved'
          : 'Learner account approved'
        : isGuardianReview
        ? 'Guardian verification needs attention'
        : 'Learner verification needs attention';
      const reviewBody = status === 'approved'
        ? 'Your Drive Tutor verification was approved. You can continue in the app.'
        : `Drive Tutor needs an update before verification can continue: ${rejectionReason}`;

      await queueNotificationEvent(admin, {
        recipientProfileId: userId,
        actorProfileId: adminUser.user_id,
        eventKey: reviewEventKey,
        title: reviewTitle,
        body: reviewBody,
        channels: ['fcm', 'email'],
        priority: 'high',
        entityType: 'profile',
        entityId: userId,
        dedupeKey: `${reviewEventKey}:${userId}:${status}:${nowIso}`,
        data: {
          screen: 'verification_status',
          review_type: reviewType,
          review_status: status,
          review_reason: status === 'rejected' ? rejectionReason : null,
          email: {
            subject: reviewTitle,
            text: reviewBody,
          },
        },
      });

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
            preferred_locations,
            profile:profiles!instructor_profiles_profile_id_fkey(
              id,
              role,
              first_name,
              last_name,
              verification_status,
              city
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

      if (status === 'approved' && requireDocumentScan) {
        const profile = Array.isArray(instructorProfile.profile)
          ? instructorProfile.profile[0]
          : instructorProfile.profile;
        const serviceAreas = mergeLocations(
          profile?.city,
          instructorProfile.preferred_locations,
        );
        const requiredCredentialDocuments = [
          'instructor_license',
          'insurance_document',
          'background_check',
        ];
        if (municipalLicenseRequired(serviceAreas)) {
          requiredCredentialDocuments.push('municipal_license');
        }
        await assertCurrentDocumentsScanned(
          admin,
          userId,
          [
            'instructor_license',
            'insurance_document',
            'background_check',
            'municipal_license',
          ],
          requiredCredentialDocuments,
        );
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

      await appendDocumentReviewEvents(
        admin,
        userId,
        [
          'instructor_license',
          'insurance_document',
          'background_check',
          'municipal_license',
        ],
        status,
        String(adminUser.user_id),
        reviewNotes,
        rejectionReason,
      );

      const rawProfile = instructorProfile.profile as unknown;
      const profile = Array.isArray(rawProfile)
        ? ((rawProfile[0] as Record<string, unknown> | undefined) ?? {})
        : ((rawProfile as Record<string, unknown> | null) ?? {});
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

      const instructorName = displayName(profile);
      const credentialEventKey = status === 'approved'
        ? 'instructor.credentials.approved'
        : 'instructor.credentials.changes_required';
      const credentialTitle = status === 'approved'
        ? 'Instructor credentials approved'
        : 'Instructor credentials need attention';
      const credentialBody = status === 'approved'
        ? 'Your instructor credentials were approved. Activate your access pass on the website to unlock instructor tools in the app.'
        : `Drive Tutor needs an update before instructor approval can continue: ${rejectionReason}`;

      await queueNotificationEvent(admin, {
        recipientProfileId: userId,
        actorProfileId: adminUser.user_id,
        eventKey: credentialEventKey,
        title: credentialTitle,
        body: credentialBody,
        channels: ['fcm', 'email'],
        priority: 'high',
        entityType: 'instructor_profile',
        entityId: userId,
        dedupeKey: `${credentialEventKey}:${userId}:${status}:${nowIso}`,
        data: {
          screen: status === 'approved' ? 'instructor_activation' : 'instructor_credentials',
          review_type: reviewType,
          review_status: status,
          review_reason: status === 'rejected' ? rejectionReason : null,
          instructor_name: instructorName,
          email: {
            subject: credentialTitle,
            text: credentialBody,
          },
        },
      });

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
