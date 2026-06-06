import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'npm:@supabase/supabase-js@2';

import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { sha256Hex } from '../_shared/hash.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const payload = await request.json();
    const authUserId = String(payload.authUserId ?? '').trim();
    const email = String(payload.email ?? '').trim().toLowerCase();
    const flowToken = String(payload.flowToken ?? '').trim();

    if (authUserId.length === 0 || email.length === 0 || flowToken.length === 0) {
      return jsonResponse(
        { error: 'Missing authUserId, email, or flowToken.' },
        400,
      );
    }

    const { data, error } = await admin.auth.admin.getUserById(authUserId);
    if (error != null || data.user == null) {
      return jsonResponse({ error: 'Auth user not found.' }, 404);
    }

    const userEmail = data.user.email?.trim().toLowerCase();
    if (userEmail != email) {
      return jsonResponse({ error: 'Email does not match auth user.' }, 400);
    }

    const flowTokenHash = await sha256Hex(flowToken);

    const { error: upsertError } = await admin.from('signup_flows').upsert(
      {
        auth_user_id: authUserId,
        email,
        flow_token_hash: flowTokenHash,
        confirmed_at: null,
        completed_at: null,
        expires_at: new Date(
          Date.now() + 2 * 24 * 60 * 60 * 1000,
        ).toISOString(),
      },
      {
        onConflict: 'auth_user_id',
      },
    );

    if (upsertError != null) {
      return jsonResponse({ error: upsertError.message }, 400);
    }

    return jsonResponse({ success: true });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error ? error.message : 'Unexpected error.',
      },
      500,
    );
  }
});
