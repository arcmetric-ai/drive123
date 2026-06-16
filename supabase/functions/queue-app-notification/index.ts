import { createClient } from 'npm:@supabase/supabase-js@2';

type JsonRow = Record<string, any>;
type NotificationChannel = 'fcm' | 'email';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function jsonResponse(body: JsonRow, status = 200) {
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

function clean(value: unknown) {
  if (typeof value !== 'string') return '';
  const trimmed = value.trim();
  return trimmed.toLowerCase() === 'null' ? '' : trimmed;
}

function displayName(profile: JsonRow | null | undefined) {
  const fullName = `${clean(profile?.first_name)} ${clean(profile?.last_name)}`.trim();
  return fullName || clean(profile?.email) || 'Drive Tutor user';
}

function formatDateTime(value: unknown) {
  const date = typeof value === 'string' ? new Date(value) : null;
  if (date == null || Number.isNaN(date.getTime())) return 'your scheduled time';
  return new Intl.DateTimeFormat('en-CA', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'America/Toronto',
  }).format(date);
}

function templateFor(
  eventKey: string,
  context: JsonRow,
): {
  title: string;
  body: string;
  screen: string;
  channels: NotificationChannel[];
  priority: 'normal' | 'high';
} {
  const learnerName = clean(context.learnerName) || 'A learner';
  const instructorName = clean(context.instructorName) || 'Your instructor';
  const recipientRole = clean(context.recipientRole);
  const lessonTime = formatDateTime(context.scheduledAt);
  const documentName = clean(context.documentName) || 'Document';

  switch (eventKey) {
    case 'learner.request.created':
      return {
        title: 'New learner request',
        body: `${learnerName} sent you a lesson request.`,
        screen: 'review_learner_request',
        channels: ['fcm', 'email'],
        priority: 'high',
      };
    case 'learner.request.cancelled':
      return {
        title: 'Learner request cancelled',
        body: `${learnerName} cancelled their lesson request.`,
        screen: 'instructor_requests',
        channels: ['fcm'],
        priority: 'normal',
      };
    case 'learner.request.accepted':
      return {
        title: 'Request accepted',
        body: `${instructorName} accepted your lesson request. You can now coordinate lessons in the app.`,
        screen: 'find_instructor',
        channels: ['fcm', 'email'],
        priority: 'high',
      };
    case 'learner.request.rejected':
      return {
        title: 'Request update',
        body: `${instructorName} could not accept your request right now.`,
        screen: 'find_instructor',
        channels: ['fcm', 'email'],
        priority: 'normal',
      };
    case 'lesson.booked':
      return {
        title: 'Lesson booked',
        body: recipientRole === 'instructor'
          ? `${learnerName} is booked with you for ${lessonTime}.`
          : `Your lesson with ${instructorName} is booked for ${lessonTime}.`,
        screen: recipientRole === 'instructor' ? 'instructor_dashboard' : 'my_lessons',
        channels: ['fcm', 'email'],
        priority: 'high',
      };
    case 'lesson.rescheduled':
      return {
        title: 'Lesson rescheduled',
        body: `Your lesson has been moved to ${lessonTime}.`,
        screen: recipientRole === 'instructor' ? 'instructor_dashboard' : 'my_lessons',
        channels: ['fcm', 'email'],
        priority: 'high',
      };
    case 'lesson.cancelled':
      return {
        title: 'Lesson cancelled',
        body: `The lesson scheduled for ${lessonTime} was cancelled.`,
        screen: recipientRole === 'instructor' ? 'instructor_dashboard' : 'my_lessons',
        channels: ['fcm', 'email'],
        priority: 'high',
      };
    case 'lesson.started':
      return {
        title: 'Lesson started',
        body: recipientRole === 'instructor'
          ? `${learnerName}'s lesson has started.`
          : `Your lesson with ${instructorName} has started.`,
        screen: recipientRole === 'instructor' ? 'instructor_dashboard' : 'my_lessons',
        channels: ['fcm'],
        priority: 'normal',
      };
    case 'lesson.ended':
      return {
        title: 'Lesson completed',
        body: 'Your lesson is complete. Add notes or review the lesson details when you have a moment.',
        screen: recipientRole === 'instructor' ? 'instructor_dashboard' : 'my_lessons',
        channels: ['fcm', 'email'],
        priority: 'normal',
      };
    case 'lesson.review.requested':
      return {
        title: 'Rate your lesson',
        body: `Tell us how your lesson with ${instructorName} went.`,
        screen: 'my_lessons',
        channels: ['fcm', 'email'],
        priority: 'normal',
      };
    case 'instructor.document.uploaded':
      return {
        title: 'Document received',
        body: `${documentName} was uploaded. Drive Tutor will review it if a review is required.`,
        screen: 'instructor_credentials',
        channels: ['fcm', 'email'],
        priority: 'normal',
      };
    default:
      return {
        title: 'Drive Tutor update',
        body: 'There is a new update in your Drive Tutor account.',
        screen: 'home',
        channels: ['fcm'],
        priority: 'normal',
      };
  }
}

async function queueNotificationEvent(
  admin: ReturnType<typeof createServiceClient>,
  input: {
    recipientProfileId: string;
    actorProfileId: string;
    eventKey: string;
    entityType: string;
    entityId: string;
    title: string;
    body: string;
    channels: NotificationChannel[];
    priority: 'normal' | 'high';
    data: JsonRow;
  },
) {
  const { data, error } = await admin
    .from('notification_events')
    .insert({
      event_key: input.eventKey,
      recipient_profile_id: input.recipientProfileId,
      actor_profile_id: input.actorProfileId,
      entity_type: input.entityType,
      entity_id: input.entityId,
      title: input.title,
      body: input.body,
      channels: input.channels,
      priority: input.priority,
      data: input.data,
      dedupe_key:
        `${input.eventKey}:${input.recipientProfileId}:${input.entityId}:${Date.now()}`,
    })
    .select('id')
    .maybeSingle();

  if (error != null) {
    throw new Error(error.message);
  }

  const eventId = String(data?.id ?? '');
  if (eventId.length === 0) return null;

  await fetch(`${supabaseUrl}/functions/v1/send-notification-event`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${serviceRoleKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ eventId }),
  }).catch((error) => {
    console.error(error instanceof Error ? error.message : 'Notification dispatch failed.');
  });

  return eventId;
}

async function buildRequestContext(
  admin: ReturnType<typeof createServiceClient>,
  requestId: string,
) {
  const { data, error } = await admin
    .from('learner_requests')
    .select(`
      id,
      learner_id,
      instructor_id,
      status,
      focus,
      learner:profiles!learner_requests_learner_id_fkey(id, first_name, last_name, email),
      instructor:profiles!learner_requests_instructor_id_fkey(id, first_name, last_name, email)
    `)
    .eq('id', requestId)
    .maybeSingle();
  if (error != null) throw new Error(error.message);
  if (data == null) throw new Error('Learner request not found.');

  const row = data as JsonRow;
  return {
    row,
    learnerName: displayName(row.learner),
    instructorName: displayName(row.instructor),
  };
}

async function buildLessonContext(
  admin: ReturnType<typeof createServiceClient>,
  lessonId: string,
) {
  const { data, error } = await admin
    .from('lessons')
    .select(`
      id,
      learner_id,
      instructor_id,
      status,
      scheduled_at,
      focus,
      learner:profiles!lessons_learner_id_fkey(id, first_name, last_name, email),
      instructor:profiles!lessons_instructor_id_fkey(id, first_name, last_name, email)
    `)
    .eq('id', lessonId)
    .maybeSingle();
  if (error != null) throw new Error(error.message);
  if (data == null) throw new Error('Lesson not found.');

  const row = data as JsonRow;
  return {
    row,
    learnerName: displayName(row.learner),
    instructorName: displayName(row.instructor),
    scheduledAt: row.scheduled_at,
  };
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405);
  }

  try {
    const authorization = request.headers.get('Authorization');
    if (authorization == null || authorization.trim().length === 0) {
      return jsonResponse({ error: 'Missing Authorization header.' }, 401);
    }

    const requestClient = createRequestClient(request);
    const {
      data: { user },
      error: userError,
    } = await requestClient.auth.getUser();
    if (userError != null || user == null) {
      return jsonResponse({ error: 'Unauthorized.' }, 401);
    }

    const payload = await request.json();
    const eventKey = clean(payload.eventKey);
    const entityId = clean(payload.entityId);
    if (!eventKey || !entityId) {
      return jsonResponse({ error: 'Missing eventKey or entityId.' }, 400);
    }

    const admin = createServiceClient();
    let recipientProfileId = '';
    let entityType = '';
    let context: JsonRow = {};

    if (eventKey.startsWith('learner.request.')) {
      const requestContext = await buildRequestContext(admin, entityId);
      const row = requestContext.row;
      entityType = 'learner_request';
      context = requestContext;

      if (eventKey === 'learner.request.created' || eventKey === 'learner.request.cancelled') {
        if (row.learner_id !== user.id) return jsonResponse({ error: 'Forbidden.' }, 403);
        recipientProfileId = String(row.instructor_id);
      } else if (
        eventKey === 'learner.request.accepted' ||
        eventKey === 'learner.request.rejected'
      ) {
        if (row.instructor_id !== user.id) return jsonResponse({ error: 'Forbidden.' }, 403);
        recipientProfileId = String(row.learner_id);
      }
    } else if (eventKey.startsWith('lesson.')) {
      const lessonContext = await buildLessonContext(admin, entityId);
      const row = lessonContext.row;
      entityType = 'lesson';
      context = lessonContext;

      const learnerId = String(row.learner_id);
      const instructorId = String(row.instructor_id);
      if (user.id !== learnerId && user.id !== instructorId) {
        return jsonResponse({ error: 'Forbidden.' }, 403);
      }
      recipientProfileId = user.id === learnerId ? instructorId : learnerId;
      if (eventKey === 'lesson.review.requested') {
        recipientProfileId = learnerId;
      }
      context.recipientRole = recipientProfileId === instructorId ? 'instructor' : 'learner';
    } else if (eventKey === 'instructor.document.uploaded') {
      entityType = 'instructor_document';
      recipientProfileId = user.id;
      context = {
        documentName: clean(payload.data?.documentName) || 'Document',
      };
    } else {
      return jsonResponse({ error: 'Unsupported eventKey.' }, 400);
    }

    if (!recipientProfileId) {
      return jsonResponse({ error: 'Unable to resolve notification recipient.' }, 400);
    }

    const template = templateFor(eventKey, context);
    const mergedData = {
      ...(payload.data && typeof payload.data === 'object' ? payload.data : {}),
      screen: template.screen,
      event_key: eventKey,
      entity_type: entityType,
      entity_id: entityId,
      email: {
        subject: template.title,
        text: template.body,
      },
    };

    const eventId = await queueNotificationEvent(admin, {
      recipientProfileId,
      actorProfileId: user.id,
      eventKey,
      entityType,
      entityId,
      title: template.title,
      body: template.body,
      channels: template.channels,
      priority: template.priority,
      data: mergedData,
    });

    return jsonResponse({ success: true, eventId });
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'Unexpected error.' },
      500,
    );
  }
});
