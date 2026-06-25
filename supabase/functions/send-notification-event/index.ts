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

function preferenceKeyForEvent(eventKey: string) {
  const key = eventKey.toLowerCase();
  if (key.startsWith('lesson.reminder')) return 'lesson_reminders_enabled';
  if (
    key.startsWith('lesson.') ||
    key.startsWith('learner.request') ||
    key.includes('booking') ||
    key.includes('schedule')
  ) {
    return 'lesson_updates_enabled';
  }
  if (
    key.includes('review') ||
    key.includes('verification') ||
    key.includes('document') ||
    key.includes('credential')
  ) {
    return 'review_updates_enabled';
  }
  if (key.startsWith('instructor.pass')) return 'pass_updates_enabled';
  if (key.includes('marketing') || key.includes('promotion')) {
    return 'marketing_enabled';
  }
  return 'support_updates_enabled';
}

function eventAllowedByPreferences(event: JsonRow, prefs: JsonRow | null) {
  if (prefs == null) return true;
  const preferenceKey = preferenceKeyForEvent(String(event.event_key ?? ''));
  return prefs[preferenceKey] !== false;
}

function escapeHtml(value: string) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function brandedEmailHtml(subject: string, text: string) {
  const safeSubject = escapeHtml(subject);
  const paragraphs = text
    .split(/\n{2,}/)
    .map((paragraph) => paragraph.trim())
    .filter((paragraph) => paragraph.length > 0)
    .map((paragraph) => `<p style="margin:0 0 16px;color:#334155;font-size:16px;line-height:1.65;">${escapeHtml(paragraph)}</p>`)
    .join('');

  return `<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${safeSubject}</title>
  </head>
  <body style="margin:0;background:#f6f8fc;font-family:Inter,Arial,sans-serif;color:#102347;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f6f8fc;padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:600px;background:#ffffff;border:1px solid #e2e8f0;border-radius:20px;overflow:hidden;">
            <tr>
              <td style="padding:28px 28px 18px;background:#ffffff;border-bottom:1px solid #eef2f7;">
                <div style="font-size:22px;font-weight:800;color:#054ada;letter-spacing:0;">Drive Tutor</div>
                <div style="margin-top:6px;font-size:13px;color:#64748b;">Ontario driver education, organized.</div>
              </td>
            </tr>
            <tr>
              <td style="padding:30px 28px;">
                <h1 style="margin:0 0 16px;color:#102347;font-size:26px;line-height:1.25;font-weight:800;">${safeSubject}</h1>
                ${paragraphs}
                <a href="https://www.drivetutor.ca" style="display:inline-block;margin-top:8px;background:#0b5fff;color:#ffffff;text-decoration:none;font-size:15px;font-weight:700;padding:13px 18px;border-radius:12px;">Open Drive Tutor</a>
              </td>
            </tr>
            <tr>
              <td style="padding:20px 28px;background:#f8fafc;border-top:1px solid #eef2f7;color:#64748b;font-size:12px;line-height:1.6;">
                You are receiving this because there was an update on your Drive Tutor account.
                Replies go to the Drive Tutor support team when a reply-to address is configured.
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
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
    const error = data.error ?? {};
    const details = Array.isArray(error.details) ? error.details : [];
    const errorCode = details
      .map((detail: JsonRow) => detail?.errorCode)
      .find((code: unknown) => typeof code === 'string');
    const status = typeof error.status === 'string' ? error.status : '';
    const message = typeof error.message === 'string' ? error.message : 'FCM send failed.';
    const enriched = [message, status, errorCode].filter(Boolean).join(' | ');
    throw new Error(enriched);
  }
  return String(data.name ?? '');
}

function isInvalidFcmTokenError(error: unknown) {
  const message = error instanceof Error ? error.message : String(error ?? '');
  return (
    message.includes('Requested entity was not found') ||
    message.includes('UNREGISTERED') ||
    message.includes('INVALID_ARGUMENT') ||
    message.includes('registration token is not a valid FCM registration token')
  );
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
    : brandedEmailHtml(subject, text);

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

  resendPayload.html = html;

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

    if (!eventAllowedByPreferences(event, prefs)) {
      await admin
        .from('notification_events')
        .update({
          status: 'cancelled',
          processed_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', event.id);
      return jsonResponse({ success: true, status: 'cancelled', reason: 'preferences' });
    }

    const channels = Array.isArray(event.channels) ? event.channels : ['fcm'];
    const results: JsonRow[] = [];

    if (channels.includes('fcm') && prefs?.fcm_enabled !== false) {
      const { data: tokens, error: tokensError } = await admin
        .from('device_tokens')
        .select('fcm_token')
        .eq('profile_id', event.recipient_profile_id)
        .eq('is_active', true);

      if (tokensError != null) throw new Error(tokensError.message);

      if ((tokens ?? []).length === 0) {
        await admin.from('notification_deliveries').insert({
          event_id: event.id,
          profile_id: event.recipient_profile_id,
          channel: 'fcm',
          status: 'skipped',
          error_message: 'No active device token for recipient.',
          attempts: 0,
        });
        results.push({ channel: 'fcm', status: 'skipped' });
      }

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
          if (isInvalidFcmTokenError(error)) {
            await admin
              .from('device_tokens')
              .update({
                is_active: false,
                revoked_at: new Date().toISOString(),
                updated_at: new Date().toISOString(),
              })
              .eq('fcm_token', row.fcm_token);
          }
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
    const hasUnsent = results.some((result) => result.status !== 'sent');
    const status = hasSent && (hasFailed || hasUnsent)
      ? 'partial'
      : hasSent
        ? 'sent'
        : 'failed';

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
