type NotificationClient = {
  from: (table: string) => {
    insert: (values: Record<string, unknown>) => {
      select: (columns: string) => {
        maybeSingle: () => Promise<{
          data: Record<string, unknown> | null;
          error: { message: string } | null;
        }>;
      };
    };
  };
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

export async function queueNotificationEvent(
  admin: NotificationClient,
  input: QueueNotificationInput,
) {
  const { data, error } = await admin.from('notification_events').insert({
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
  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
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

export function displayName(profile: Record<string, unknown> | null | undefined) {
  const firstName = String(profile?.first_name ?? '').trim();
  const lastName = String(profile?.last_name ?? '').trim();
  const fullName = `${firstName} ${lastName}`.trim();
  return fullName.length > 0 ? fullName : 'Drive Tutor user';
}
