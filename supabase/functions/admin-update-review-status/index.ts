import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'npm:@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

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

function createServiceClient() {
  return createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

function createRequestClient(request: Request) {
  return createClient(supabaseUrl, anonKey, {
    global: {
      headers: {
        Authorization: request.headers.get('Authorization') ?? '',
      },
    },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

async function requireAdmin(request: Request) {
  const authorization = request.headers.get('Authorization');
  if (authorization == null || authorization.trim().length === 0) {
    return {
      error: jsonResponse({ error: 'Missing Authorization header.' }, 401),
    };
  }

  const requestClient = createRequestClient(request);
  const {
    data: { user },
    error: userError,
  } = await requestClient.auth.getUser();

  if (userError != null || user == null) {
    return {
      error: jsonResponse({ error: 'Unauthorized.' }, 401),
    };
  }

  const admin = createServiceClient();
  const { data: adminRow, error: adminError } = await admin
    .from('admin_users')
    .select('user_id, email')
    .eq('user_id', user.id)
    .maybeSingle();

  if (adminError != null) {
    return {
      error: jsonResponse({ error: adminError.message }, 500),
    };
  }

  if (adminRow == null) {
    return {
      error: jsonResponse({ error: 'Forbidden.' }, 403),
    };
  }

  return { admin, user, adminUser: adminRow };
}

async function queueNotificationEvent(
  admin: ReturnType<typeof createServiceClient>,
  input: QueueNotificationInput,
) {
  const { data, error } = await admin
    .from('notification_events')
    .insert({
      event_key: input.eventKey,
      recipient_profile_id: input.recipientProfileId,
      actor_profile_id: input.actorProfileId ?? null,
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
      let isGuardianReview = false;

      if (isLearner) {
        const { data: learnerProfile, error: learnerProfileError } = await admin
          .from('learner_profiles')
          .select('account_type, ward_first_name, ward_last_name')
          .eq('profile_id', userId)
          .maybeSingle();

        if (learnerProfileError != null) {
          return jsonResponse({ error: learnerProfileError.message }, 400);
        }

        isGuardianReview =
          String(learnerProfile?.account_type ?? '').trim().toLowerCase() ===
            'guardian';
      }

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
            profile:profiles!instructor_profiles_profile_id_fkey(
              id,
              role,
              first_name,
              last_name,
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
