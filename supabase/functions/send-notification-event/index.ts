import { createClient } from 'npm:@supabase/supabase-js@2';

type JsonRow = Record<string, any>;

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const resendApiKey = Deno.env.get('RESEND_API_KEY') ?? '';
const resendFromEmail = Deno.env.get('RESEND_FROM_EMAIL') ?? '';
const resendReplyToEmail = Deno.env.get('RESEND_REPLY_TO_EMAIL') ?? '';

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

let cachedFcmToken: { accessToken: string; expiresAt: number } | null = null;

function createServiceClient() {
  return createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

function base64Url(input: ArrayBuffer | Uint8Array | string) {
  const bytes =
    typeof input === 'string'
      ? new TextEncoder().encode(input)
      : input instanceof Uint8Array
        ? input
        : new Uint8Array(input);

  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

function pemToArrayBuffer(pem: string) {
  const body = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const binary = atob(body);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes.buffer;
}

function firebaseConfig() {
  const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
  if (serviceAccountJson != null && serviceAccountJson.trim().length > 0) {
    const parsed = JSON.parse(serviceAccountJson);
    return {
      projectId: String(parsed.project_id ?? ''),
      clientEmail: String(parsed.client_email ?? ''),
      privateKey: String(parsed.private_key ?? '').replaceAll('\\n', '\n'),
    };
  }

  return {
    projectId: Deno.env.get('FIREBASE_PROJECT_ID') ?? '',
    clientEmail: Deno.env.get('FIREBASE_CLIENT_EMAIL') ?? '',
    privateKey: (Deno.env.get('FIREBASE_PRIVATE_KEY') ?? '').replaceAll('\\n', '\n'),
  };
}

function notificationDataForFcm(data: JsonRow) {
  return Object.fromEntries(
    Object.entries(data ?? {})
      .filter(([key, value]) => (
        key !== 'email' &&
        ['string', 'number', 'boolean'].includes(typeof value)
      ))
      .map(([key, value]) => [key, String(value)]),
  );
}

async function createFirebaseJwt(clientEmail: string, privateKey: string) {
  const nowSeconds = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const claim = {
    iss: clientEmail,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: nowSeconds,
    exp: nowSeconds + 3600,
  };

  const unsigned = `${base64Url(JSON.stringify(header))}.${base64Url(JSON.stringify(claim))}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(privateKey),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );

  return `${unsigned}.${base64Url(signature)}`;
}

async function getFcmAccessToken() {
  const now = Date.now();
  if (cachedFcmToken != null && cachedFcmToken.expiresAt > now + 60_000) {
    return cachedFcmToken.accessToken;
  }

  const config = firebaseConfig();
  if (!config.projectId || !config.clientEmail || !config.privateKey) {
    throw new Error('Firebase service account is not configured.');
  }

  const assertion = await createFirebaseJwt(config.clientEmail, config.privateKey);
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  const data = await response.json() as JsonRow;
  if (!response.ok) {
    throw new Error(data.error_description ?? data.error ?? 'Unable to create FCM access token.');
  }

  cachedFcmToken = {
    accessToken: String(data.access_token),
    expiresAt: now + Number(data.expires_in ?? 3600) * 1000,
  };
  return cachedFcmToken.accessToken;
}

async function sendFcm(token: string, event: JsonRow) {
  const config = firebaseConfig();
  const accessToken = await getFcmAccessToken();
  const payload = {
    message: {
      token,
      notification: {
        title: String(event.title),
        body: String(event.body),
      },
      data: notificationDataForFcm(event.data ?? {}),
      android: {
        priority: event.priority === 'high' ? 'HIGH' : 'NORMAL',
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
          },
        },
      },
    },
  };

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${config.projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    },
  );

  const data = await response.json() as JsonRow;
  if (!response.ok) {
    throw new Error(data.error?.message ?? 'FCM send failed.');
  }
  return String(data.name ?? '');
}

async function sendEmail(email: string, event: JsonRow) {
  if (!resendApiKey || !resendFromEmail) {
    throw new Error('Resend is not configured.');
  }

  const emailData = event.data?.email && typeof event.data.email === 'object'
    ? event.data.email as JsonRow
    : {};

  const subject = String(emailData.subject ?? event.title);
  const text = String(emailData.text ?? event.body);
  const html = typeof emailData.html === 'string' && emailData.html.trim().length > 0
    ? String(emailData.html)
    : undefined;

  const resendPayload: JsonRow = {
    from: resendFromEmail,
    to: email,
    subject,
    text,
    tags: [
      {
        name: 'event_key',
        value: String(event.event_key).replace(/[^a-zA-Z0-9_-]/g, '_').slice(0, 256),
      },
    ],
  };

  if (html != null) {
    resendPayload.html = html;
  }

  if (resendReplyToEmail.trim().length > 0) {
    resendPayload.reply_to = [resendReplyToEmail];
  }

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${resendApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(resendPayload),
  });

  const data = await response.json() as JsonRow;
  if (!response.ok) {
    throw new Error(data.message ?? 'Resend send failed.');
  }
  return String(data.id ?? '');
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405);
  }

  const admin = createServiceClient();

  try {
    const payload = await request.json();
    const eventId = String(payload.eventId ?? '').trim();
    const dedupeKey = String(payload.dedupeKey ?? '').trim();

    if (eventId.length === 0 && dedupeKey.length === 0) {
      return jsonResponse({ error: 'Missing eventId or dedupeKey.' }, 400);
    }

    let query = admin
      .from('notification_events')
      .select('*')
      .lte('scheduled_for', new Date().toISOString())
      .limit(1);

    query = eventId.length > 0 ? query.eq('id', eventId) : query.eq('dedupe_key', dedupeKey);

    const { data: events, error: eventError } = await query;
    if (eventError != null) return jsonResponse({ error: eventError.message }, 400);

    const event = events?.[0];
    if (event == null) return jsonResponse({ error: 'Notification event not found.' }, 404);
    if (event.status === 'sent') return jsonResponse({ success: true, alreadySent: true });

    await admin
      .from('notification_events')
      .update({ status: 'processing', updated_at: new Date().toISOString() })
      .eq('id', event.id);

    const { data: profile, error: profileError } = await admin
      .from('profiles')
      .select('id, email')
      .eq('id', event.recipient_profile_id)
      .maybeSingle();
    if (profileError != null) throw new Error(profileError.message);
    if (profile == null) throw new Error('Recipient profile not found.');

    const { data: prefs } = await admin
      .from('notification_preferences')
      .select('*')
      .eq('profile_id', event.recipient_profile_id)
      .maybeSingle();

    const channels = Array.isArray(event.channels) ? event.channels : ['fcm'];
    const results: JsonRow[] = [];

    if (channels.includes('fcm') && prefs?.fcm_enabled !== false) {
      const { data: tokens, error: tokensError } = await admin
        .from('device_tokens')
        .select('fcm_token')
        .eq('profile_id', event.recipient_profile_id)
        .eq('is_active', true);

      if (tokensError != null) throw new Error(tokensError.message);

      for (const row of tokens ?? []) {
        try {
          const providerId = await sendFcm(String(row.fcm_token), event);
          await admin.from('notification_deliveries').insert({
            event_id: event.id,
            profile_id: event.recipient_profile_id,
            channel: 'fcm',
            destination: row.fcm_token,
            status: 'sent',
            provider_message_id: providerId,
            attempts: 1,
            sent_at: new Date().toISOString(),
          });
          results.push({ channel: 'fcm', status: 'sent' });
        } catch (error) {
          await admin.from('notification_deliveries').insert({
            event_id: event.id,
            profile_id: event.recipient_profile_id,
            channel: 'fcm',
            destination: row.fcm_token,
            status: 'failed',
            error_message: error instanceof Error ? error.message : 'FCM failed.',
            attempts: 1,
          });
          results.push({ channel: 'fcm', status: 'failed' });
        }
      }
    }

    if (channels.includes('email') && prefs?.email_enabled !== false) {
      try {
        const providerId = await sendEmail(String(profile.email), event);
        await admin.from('notification_deliveries').insert({
          event_id: event.id,
          profile_id: event.recipient_profile_id,
          channel: 'email',
          destination: profile.email,
          status: 'sent',
          provider_message_id: providerId,
          attempts: 1,
          sent_at: new Date().toISOString(),
        });
        results.push({ channel: 'email', status: 'sent' });
      } catch (error) {
        await admin.from('notification_deliveries').insert({
          event_id: event.id,
          profile_id: event.recipient_profile_id,
          channel: 'email',
          destination: profile.email,
          status: 'failed',
          error_message: error instanceof Error ? error.message : 'Email failed.',
          attempts: 1,
        });
        results.push({ channel: 'email', status: 'failed' });
      }
    }

    const hasSent = results.some((result) => result.status === 'sent');
    const hasFailed = results.some((result) => result.status === 'failed');
    const status = hasSent && hasFailed ? 'partial' : hasSent ? 'sent' : 'failed';

    await admin
      .from('notification_events')
      .update({
        status,
        processed_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        error_message: status === 'failed' ? 'No notification channel succeeded.' : null,
      })
      .eq('id', event.id);

    return jsonResponse({ success: hasSent, status, results });
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'Unexpected error.' },
      500,
    );
  }
});
