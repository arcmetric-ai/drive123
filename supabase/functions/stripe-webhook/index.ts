import { createClient } from 'npm:@supabase/supabase-js@2';

type StripeObject = Record<string, unknown> & {
  id: string;
  metadata?: Record<string, string>;
};

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY')!;
const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET')!;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
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

function textEncoder() {
  return new TextEncoder();
}

function toHex(buffer: ArrayBuffer) {
  return [...new Uint8Array(buffer)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function timingSafeEqual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let result = 0;
  for (let index = 0; index < a.length; index += 1) {
    result |= a.charCodeAt(index) ^ b.charCodeAt(index);
  }
  return result === 0;
}

async function verifyStripeSignature(body: string, signature: string | null) {
  if (signature == null) return false;
  const parts = new Map<string, string[]>();
  for (const pair of signature.split(',')) {
    const [key, value] = pair.split('=');
    if (!key || !value) continue;
    parts.set(key, [...(parts.get(key) ?? []), value]);
  }

  const timestamp = parts.get('t')?.[0];
  const signatures = parts.get('v1') ?? [];
  if (timestamp == null || signatures.length === 0) return false;

  const timestampSeconds = Number(timestamp);
  if (!Number.isFinite(timestampSeconds)) return false;
  const ageSeconds = Math.abs(Date.now() / 1000 - timestampSeconds);
  if (ageSeconds > 300) return false;

  const key = await crypto.subtle.importKey(
    'raw',
    textEncoder().encode(webhookSecret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signedPayload = `${timestamp}.${body}`;
  const digest = await crypto.subtle.sign(
    'HMAC',
    key,
    textEncoder().encode(signedPayload),
  );
  const expected = toHex(digest);
  return signatures.some((value) => timingSafeEqual(value, expected));
}

async function stripeGet(path: string) {
  const response = await fetch(`https://api.stripe.com/v1/${path}`, {
    headers: {
      Authorization: `Bearer ${stripeSecretKey}`,
    },
  });
  const data = await response.json() as Record<string, any>;
  if (!response.ok) {
    throw new Error(data?.error?.message ?? 'Stripe request failed.');
  }
  return data as StripeObject;
}

function isoFromUnix(value: unknown) {
  if (typeof value !== 'number') return null;
  return new Date(value * 1000).toISOString();
}

function addDaysIso(days: number) {
  const date = new Date();
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString();
}

async function planAccessDays(admin: ReturnType<typeof createServiceClient>, planKey: string) {
  const { data, error } = await admin
    .from('instructor_billing_plans')
    .select('access_days')
    .eq('plan_key', planKey)
    .maybeSingle();
  if (error != null) throw new Error(error.message);
  return Number(data?.access_days ?? 1);
}

async function upsertEntitlement(
  admin: ReturnType<typeof createServiceClient>,
  values: Record<string, unknown>,
) {
  const { error } = await admin
    .from('instructor_billing_entitlements')
    .upsert(
      {
        ...values,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'profile_id' },
    );
  if (error != null) throw new Error(error.message);
}

async function handleCheckoutCompleted(
  admin: ReturnType<typeof createServiceClient>,
  session: StripeObject,
  eventId: string,
) {
  const profileId = session.metadata?.profile_id;
  const planKey = session.metadata?.plan_key;
  if (!profileId || !planKey) return;

  const nowIso = new Date().toISOString();
  const mode = String(session.mode ?? '');
  const customerId = typeof session.customer === 'string' ? session.customer : null;

  if (mode === 'subscription' && typeof session.subscription === 'string') {
    const subscription = await stripeGet(`subscriptions/${session.subscription}`);
    await upsertEntitlement(admin, {
      profile_id: profileId,
      plan_key: planKey,
      status: String(subscription.status ?? 'incomplete'),
      stripe_customer_id: customerId,
      stripe_subscription_id: subscription.id,
      stripe_checkout_session_id: session.id,
      current_period_start: isoFromUnix(subscription.current_period_start),
      current_period_end: isoFromUnix(subscription.current_period_end),
      access_starts_at: isoFromUnix(subscription.current_period_start) ?? nowIso,
      access_expires_at:
        isoFromUnix(subscription.current_period_end) ?? addDaysIso(30),
      cancel_at_period_end: Boolean(subscription.cancel_at_period_end),
      last_stripe_event_id: eventId,
    });
    return;
  }

  const accessDays = await planAccessDays(admin, planKey);
  await upsertEntitlement(admin, {
    profile_id: profileId,
    plan_key: planKey,
    status: 'active',
    stripe_customer_id: customerId,
    stripe_checkout_session_id: session.id,
    stripe_payment_intent_id:
      typeof session.payment_intent === 'string' ? session.payment_intent : null,
    access_starts_at: nowIso,
    access_expires_at: addDaysIso(accessDays),
    last_stripe_event_id: eventId,
  });
}

async function handleSubscriptionEvent(
  admin: ReturnType<typeof createServiceClient>,
  subscription: StripeObject,
  eventId: string,
  forceCanceled = false,
) {
  let profileId = subscription.metadata?.profile_id;
  let planKey = subscription.metadata?.plan_key;

  if (!profileId || !planKey) {
    const { data, error } = await admin
      .from('instructor_billing_entitlements')
      .select('profile_id, plan_key')
      .eq('stripe_subscription_id', subscription.id)
      .maybeSingle();
    if (error != null) throw new Error(error.message);
    profileId = data?.profile_id;
    planKey = data?.plan_key;
  }

  if (!profileId || !planKey) return;

  const nowIso = new Date().toISOString();
  const periodEnd =
    isoFromUnix(subscription.current_period_end) ?? (forceCanceled ? nowIso : addDaysIso(30));

  await upsertEntitlement(admin, {
    profile_id: profileId,
    plan_key: planKey,
    status: forceCanceled ? 'canceled' : String(subscription.status ?? 'incomplete'),
    stripe_customer_id:
      typeof subscription.customer === 'string' ? subscription.customer : null,
    stripe_subscription_id: subscription.id,
    current_period_start: isoFromUnix(subscription.current_period_start),
    current_period_end: periodEnd,
    access_starts_at: isoFromUnix(subscription.current_period_start) ?? nowIso,
    access_expires_at: forceCanceled ? nowIso : periodEnd,
    cancel_at_period_end: Boolean(subscription.cancel_at_period_end),
    last_stripe_event_id: eventId,
  });
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405);
  }

  if (!stripeSecretKey || !webhookSecret) {
    return jsonResponse({ error: 'Stripe webhook is not configured.' }, 500);
  }

  const body = await request.text();
  const isValid = await verifyStripeSignature(
    body,
    request.headers.get('stripe-signature'),
  );
  if (!isValid) {
    return jsonResponse({ error: 'Invalid Stripe signature.' }, 400);
  }

  const event = JSON.parse(body) as {
    id: string;
    type: string;
    data: { object: StripeObject };
  };

  const admin = createServiceClient();
  const { error: eventInsertError } = await admin
    .from('stripe_webhook_events')
    .insert({ event_id: event.id, event_type: event.type });

  if (eventInsertError != null) {
    if (eventInsertError.code === '23505') {
      return jsonResponse({ received: true, duplicate: true });
    }
    return jsonResponse({ error: eventInsertError.message }, 500);
  }

  try {
    if (event.type === 'checkout.session.completed') {
      await handleCheckoutCompleted(admin, event.data.object, event.id);
    } else if (
      event.type === 'customer.subscription.created' ||
      event.type === 'customer.subscription.updated'
    ) {
      await handleSubscriptionEvent(admin, event.data.object, event.id);
    } else if (event.type === 'customer.subscription.deleted') {
      await handleSubscriptionEvent(admin, event.data.object, event.id, true);
    } else if (event.type === 'invoice.payment_failed') {
      const subscriptionId = event.data.object.subscription;
      if (typeof subscriptionId === 'string') {
        const subscription = await stripeGet(`subscriptions/${subscriptionId}`);
        await handleSubscriptionEvent(admin, subscription, event.id);
      }
    }
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'Webhook failed.' },
      500,
    );
  }

  return jsonResponse({ received: true });
});
