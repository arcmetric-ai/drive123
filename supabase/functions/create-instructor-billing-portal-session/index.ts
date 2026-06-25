import { createClient } from 'npm:@supabase/supabase-js@2';

import { corsHeaders, jsonResponse } from '../_shared/cors.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY')!;
const configuredReturnUrl = Deno.env.get('STRIPE_BILLING_PORTAL_RETURN_URL');
const portalConfigurationId = Deno.env.get('STRIPE_BILLING_PORTAL_CONFIGURATION_ID');
const fallbackReturnUrl = 'https://www.drivetutor.ca/instructor-dashboard';

type PortalIntent = 'manage' | 'receipts' | 'upgrade_yearly';

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

function createServiceClient() {
  return createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

function appendForm(
  form: URLSearchParams,
  value: string | number | boolean | null | undefined,
  key: string,
) {
  if (value == null || String(value).trim().length === 0) return;
  form.append(key, String(value));
}

function isAllowedReturnHost(hostname: string) {
  return hostname === 'localhost' ||
    hostname === '127.0.0.1' ||
    hostname === 'drivetutor.ca' ||
    hostname === 'www.drivetutor.ca' ||
    hostname.endsWith('.drivetutor.ca');
}

function safeReturnUrl(rawReturnUrl: unknown, request: Request) {
  const origin = request.headers.get('origin');
  const originReturnUrl = origin ? `${origin}/instructor-dashboard` : null;
  const candidates = [
    configuredReturnUrl,
    typeof rawReturnUrl === 'string' ? rawReturnUrl : null,
    originReturnUrl,
    fallbackReturnUrl,
  ];

  for (const candidate of candidates) {
    if (candidate == null || candidate.trim().length === 0) continue;
    try {
      const url = new URL(candidate);
      if (!['http:', 'https:'].includes(url.protocol)) continue;
      if (!isAllowedReturnHost(url.hostname)) continue;
      return url.toString();
    } catch (_) {
      // Keep checking the next candidate.
    }
  }

  return fallbackReturnUrl;
}

async function stripePost(path: string, body: URLSearchParams) {
  const response = await fetch(`https://api.stripe.com/v1/${path}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${stripeSecretKey}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body,
  });

  const data = await response.json() as { url?: string; error?: { message?: string } };
  if (!response.ok) {
    const message = data.error?.message ?? 'Stripe billing portal request failed.';
    if (message.toLowerCase().includes('configuration')) {
      throw new Error(
        `${message} Enable the Stripe customer portal for the current Stripe mode, or set STRIPE_BILLING_PORTAL_CONFIGURATION_ID in Supabase secrets.`,
      );
    }
    throw new Error(message);
  }
  return data;
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
  return data;
}

function subscriptionItemId(subscription: Record<string, any>) {
  const items = subscription.items?.data;
  if (!Array.isArray(items) || items.length !== 1) {
    throw new Error('This subscription cannot be upgraded automatically. Please use Manage Pass.');
  }
  const itemId = items[0]?.id;
  if (typeof itemId !== 'string' || itemId.trim().length === 0) {
    throw new Error('Stripe did not return a subscription item to update.');
  }
  return itemId;
}

async function addYearlyUpgradeFlow(
  admin: ReturnType<typeof createServiceClient>,
  form: URLSearchParams,
  profileId: string,
  stripeCustomerId: string,
) {
  const { data: entitlement, error: entitlementError } = await admin
    .from('instructor_billing_entitlements')
    .select('plan_key, status, access_expires_at, stripe_subscription_id')
    .eq('profile_id', profileId)
    .maybeSingle();

  if (entitlementError != null) {
    throw new Error(entitlementError.message);
  }
  if (!entitlement || entitlement.plan_key !== 'monthly_pass') {
    throw new Error('Annual upgrade is available only from an active monthly subscription.');
  }
  if (!['active', 'trialing'].includes(String(entitlement.status))) {
    throw new Error('Your monthly subscription must be active before upgrading.');
  }
  const expiresAt = new Date(String(entitlement.access_expires_at)).getTime();
  if (!Number.isFinite(expiresAt) || expiresAt <= Date.now()) {
    throw new Error('Your monthly subscription must be active before upgrading.');
  }
  const subscriptionId = String(entitlement.stripe_subscription_id ?? '');
  if (subscriptionId.length === 0) {
    throw new Error('No Stripe subscription record was found for this monthly pass.');
  }

  const { data: annualPlan, error: planError } = await admin
    .from('instructor_billing_plans')
    .select('stripe_price_env')
    .eq('plan_key', 'yearly_pass')
    .eq('is_active', true)
    .maybeSingle();

  if (planError != null) {
    throw new Error(planError.message);
  }
  const priceEnv = String(annualPlan?.stripe_price_env ?? 'STRIPE_PRICE_YEARLY_PASS');
  const yearlyPriceId = Deno.env.get(priceEnv);
  if (!yearlyPriceId) {
    throw new Error(`Missing Stripe price env ${priceEnv}.`);
  }

  const subscription = await stripeGet(`subscriptions/${subscriptionId}`);
  if (subscription.customer !== stripeCustomerId) {
    throw new Error('Stripe subscription does not belong to this instructor.');
  }

  form.append('flow_data[type]', 'subscription_update_confirm');
  form.append('flow_data[subscription_update_confirm][subscription]', subscriptionId);
  form.append('flow_data[subscription_update_confirm][items][0][id]', subscriptionItemId(subscription));
  form.append('flow_data[subscription_update_confirm][items][0][quantity]', '1');
  form.append('flow_data[subscription_update_confirm][items][0][price]', yearlyPriceId);
  form.append('flow_data[after_completion][type]', 'redirect');
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405);
  }

  if (!stripeSecretKey) {
    return jsonResponse({ error: 'Stripe billing portal is not configured.' }, 500);
  }

  const requestClient = createRequestClient(request);
  const {
    data: { user },
    error: userError,
  } = await requestClient.auth.getUser();

  if (userError != null || user == null) {
    return jsonResponse({ error: 'Unauthorized.' }, 401);
  }

  const body = await request.json().catch(() => ({})) as {
    intent?: unknown;
    returnUrl?: unknown;
  };
  const intent: PortalIntent =
    body.intent === 'upgrade_yearly' ? 'upgrade_yearly' : body.intent === 'receipts' ? 'receipts' : 'manage';
  const admin = createServiceClient();

  const { data: profile, error: profileError } = await admin
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .maybeSingle();

  if (profileError != null) {
    return jsonResponse({ error: profileError.message }, 500);
  }
  if (profile?.role !== 'instructor') {
    return jsonResponse({ error: 'Only instructor accounts can open billing records.' }, 403);
  }

  const { data: customer, error: customerError } = await admin
    .from('instructor_stripe_customers')
    .select('stripe_customer_id')
    .eq('profile_id', user.id)
    .maybeSingle();

  if (customerError != null) {
    return jsonResponse({ error: customerError.message }, 500);
  }
  if (!customer?.stripe_customer_id) {
    return jsonResponse(
      { error: 'No Stripe customer record was found for this instructor.' },
      404,
    );
  }

  try {
    const returnUrl = safeReturnUrl(body.returnUrl, request);
    const portalForm = new URLSearchParams();
    appendForm(portalForm, customer.stripe_customer_id, 'customer');
    appendForm(portalForm, returnUrl, 'return_url');
    appendForm(portalForm, portalConfigurationId, 'configuration');
    if (intent === 'upgrade_yearly') {
      await addYearlyUpgradeFlow(
        admin,
        portalForm,
        user.id,
        customer.stripe_customer_id,
      );
      appendForm(portalForm, returnUrl, 'flow_data[after_completion][redirect][return_url]');
    }

    const session = await stripePost('billing_portal/sessions', portalForm);
    if (!session.url) {
      return jsonResponse({ error: 'Stripe did not return a billing portal URL.' }, 502);
    }

    return jsonResponse({ url: session.url });
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'Unable to open billing portal.' },
      502,
    );
  }
});
