import { createClient } from 'npm:@supabase/supabase-js@2';

type BillingPlan = {
  plan_key: string;
  display_name: string;
  billing_interval: 'day' | 'month' | 'year';
  access_days: number;
  stripe_price_env: string;
};

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const stripeSecretKey = Deno.env.get('STRIPE_SECRET_KEY')!;
const successUrl = Deno.env.get('STRIPE_CHECKOUT_SUCCESS_URL')!;
const cancelUrl = Deno.env.get('STRIPE_CHECKOUT_CANCEL_URL')!;
const configuredTrialDays = Number(Deno.env.get('STRIPE_INSTRUCTOR_TRIAL_DAYS') ?? '60');
const instructorTrialDays = Number.isFinite(configuredTrialDays) && configuredTrialDays > 0
  ? Math.floor(configuredTrialDays)
  : 60;

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
  if (value == null) return;
  form.append(key, String(value));
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

  const data = await response.json() as Record<string, any>;
  if (!response.ok) {
    throw new Error(data?.error?.message ?? 'Stripe request failed.');
  }
  return data as Record<string, unknown>;
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405);
  }

  if (!stripeSecretKey || !successUrl || !cancelUrl) {
    return jsonResponse({ error: 'Stripe checkout is not configured.' }, 500);
  }

  const requestClient = createRequestClient(request);
  const {
    data: { user },
    error: userError,
  } = await requestClient.auth.getUser();

  if (userError != null || user == null) {
    return jsonResponse({ error: 'Unauthorized.' }, 401);
  }

  const { planKey } = await request.json().catch(() => ({ planKey: null }));
  if (typeof planKey !== 'string' || planKey.trim().length === 0) {
    return jsonResponse({ error: 'Missing planKey.' }, 400);
  }

  const admin = createServiceClient();

  const { data: profile, error: profileError } = await admin
    .from('profiles')
    .select('id, email, role, first_name, last_name')
    .eq('id', user.id)
    .maybeSingle();

  if (profileError != null) {
    return jsonResponse({ error: profileError.message }, 500);
  }
  if (profile == null || profile.role !== 'instructor') {
    return jsonResponse({ error: 'Only instructor accounts can buy passes.' }, 403);
  }

  const { data: instructorProfile, error: instructorError } = await admin
    .from('instructor_profiles')
    .select('credentials_status')
    .eq('profile_id', user.id)
    .maybeSingle();

  if (instructorError != null) {
    return jsonResponse({ error: instructorError.message }, 500);
  }
  if (instructorProfile?.credentials_status !== 'approved') {
    return jsonResponse(
      { error: 'Instructor credentials must be approved before buying a pass.' },
      403,
    );
  }

  const { data: planRow, error: planError } = await admin
    .from('instructor_billing_plans')
    .select(
      'plan_key, display_name, billing_interval, access_days, stripe_price_env',
    )
    .eq('plan_key', planKey)
    .eq('is_active', true)
    .maybeSingle();

  if (planError != null) {
    return jsonResponse({ error: planError.message }, 500);
  }
  if (planRow == null) {
    return jsonResponse({ error: 'Unknown billing plan.' }, 404);
  }
  const plan = planRow as BillingPlan;

  const priceId = Deno.env.get(plan.stripe_price_env);
  if (priceId == null || priceId.trim().length === 0) {
    return jsonResponse(
      { error: `Missing Stripe price env ${plan.stripe_price_env}.` },
      500,
    );
  }

  let stripeCustomerId: string | null = null;
  const { data: existingCustomer, error: customerError } = await admin
    .from('instructor_stripe_customers')
    .select('stripe_customer_id')
    .eq('profile_id', user.id)
    .maybeSingle();

  if (customerError != null) {
    return jsonResponse({ error: customerError.message }, 500);
  }
  stripeCustomerId = existingCustomer?.stripe_customer_id ?? null;

  if (stripeCustomerId == null) {
    const customerForm = new URLSearchParams();
    appendForm(customerForm, profile.email ?? user.email, 'email');
    appendForm(
      customerForm,
      `${profile.first_name ?? ''} ${profile.last_name ?? ''}`.trim(),
      'name',
    );
    appendForm(customerForm, user.id, 'metadata[profile_id]');

    const customer = await stripePost('customers', customerForm);
    stripeCustomerId = String(customer.id);

    const { error: upsertError } = await admin
      .from('instructor_stripe_customers')
      .upsert(
        {
          profile_id: user.id,
          stripe_customer_id: stripeCustomerId,
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'profile_id' },
      );

    if (upsertError != null) {
      return jsonResponse({ error: upsertError.message }, 500);
    }
  }

  const mode = plan.billing_interval === 'day' ? 'payment' : 'subscription';
  const sessionForm = new URLSearchParams();
  appendForm(sessionForm, mode, 'mode');
  appendForm(sessionForm, stripeCustomerId, 'customer');
  appendForm(sessionForm, user.id, 'client_reference_id');
  appendForm(sessionForm, successUrl, 'success_url');
  appendForm(sessionForm, cancelUrl, 'cancel_url');
  appendForm(sessionForm, priceId, 'line_items[0][price]');
  appendForm(sessionForm, 1, 'line_items[0][quantity]');
  appendForm(sessionForm, user.id, 'metadata[profile_id]');
  appendForm(sessionForm, plan.plan_key, 'metadata[plan_key]');
  appendForm(sessionForm, true, 'allow_promotion_codes');

  if (mode === 'subscription') {
    appendForm(sessionForm, user.id, 'subscription_data[metadata][profile_id]');
    appendForm(sessionForm, plan.plan_key, 'subscription_data[metadata][plan_key]');
    appendForm(sessionForm, instructorTrialDays, 'subscription_data[trial_period_days]');
  } else {
    appendForm(sessionForm, user.id, 'payment_intent_data[metadata][profile_id]');
    appendForm(sessionForm, plan.plan_key, 'payment_intent_data[metadata][plan_key]');
  }

  const session = await stripePost('checkout/sessions', sessionForm);

  return jsonResponse({
    id: session.id,
    url: session.url,
  });
});
