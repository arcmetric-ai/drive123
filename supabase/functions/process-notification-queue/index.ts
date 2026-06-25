import { createClient } from 'npm:@supabase/supabase-js@2';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const cronSecret = Deno.env.get('CRON_SECRET') ?? '';

function response(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return response({ error: 'Method not allowed.' }, 405);
  }

  if (!cronSecret || request.headers.get('x-cron-secret') !== cronSecret) {
    return response({ error: 'Unauthorized.' }, 401);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: queuedReminders, error: reminderError } = await admin.rpc(
    'queue_due_lesson_reminders',
  );
  if (reminderError != null) {
    console.error('process-notification-queue reminder RPC failed', {
      error: reminderError.message,
    });
    return response({ error: reminderError.message }, 500);
  }

  const { data: events, error } = await admin
    .from('notification_events')
    .select('id')
    .eq('status', 'queued')
    .lte('scheduled_for', new Date().toISOString())
    .order('scheduled_for', { ascending: true })
    .limit(50);

  if (error != null) {
    console.error('process-notification-queue event fetch failed', {
      error: error.message,
    });
    return response({ error: error.message }, 500);
  }

  const results = await Promise.allSettled(
    (events ?? []).map(async (event) => {
      const dispatch = await fetch(
        `${supabaseUrl}/functions/v1/send-notification-event`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${serviceRoleKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ eventId: event.id }),
        },
      );
      if (!dispatch.ok) {
        throw new Error(await dispatch.text());
      }
      return event.id;
    }),
  );

  const processed = results.filter((result) => result.status === 'fulfilled').length;
  const failed = results.filter((result) => result.status === 'rejected').length;
  const failedEventIds = results
    .map((result, index) => (
      result.status === 'rejected' ? events?.[index]?.id : null
    ))
    .filter((eventId): eventId is string => typeof eventId === 'string');

  if (failed > 0) {
    console.error('process-notification-queue dispatch failures', {
      failed,
      failedEventIds,
    });
  }

  console.log('process-notification-queue completed', {
    queuedReminders: queuedReminders ?? 0,
    dueEvents: events?.length ?? 0,
    processed,
    failed,
  });

  return response({
    queuedReminders: queuedReminders ?? 0,
    processed,
    failed,
  });
});
