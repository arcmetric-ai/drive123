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
    const flowToken = String(payload.flowToken ?? '').trim();

    if (authUserId.length === 0 || flowToken.length === 0) {
      return jsonResponse({ error: 'Missing authUserId or flowToken.' }, 400);
    }

    const flowTokenHash = await sha256Hex(flowToken);
    const nowIso = new Date().toISOString();
    const { data: flow, error: flowError } = await admin
      .from('signup_flows')
      .select('auth_user_id, confirmed_at, completed_at, expires_at')
      .eq('auth_user_id', authUserId)
      .eq('flow_token_hash', flowTokenHash)
      .gt('expires_at', nowIso)
      .maybeSingle();

    if (flowError != null) {
      return jsonResponse({ error: flowError.message }, 400);
    }

    if (flow == null) {
      return jsonResponse({ confirmed: false, reason: 'flow_not_found' });
    }

    const { data, error } = await admin.auth.admin.getUserById(authUserId);
    if (error != null || data.user == null) {
      return jsonResponse({ error: 'Auth user not found.' }, 404);
    }

    const emailConfirmedAt =
      (data.user as { email_confirmed_at?: string | null }).email_confirmed_at;
    const confirmed = emailConfirmedAt != null;

    if (confirmed && flow['confirmed_at'] == null) {
      await admin.from('signup_flows').update({
        'confirmed_at': emailConfirmedAt,
      }).eq('auth_user_id', authUserId);
    }

    return jsonResponse({
      'confirmed': confirmed,
      'email': data.user.email,
      'completed': flow['completed_at'] != null,
    });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error ? error.message : 'Unexpected error.',
      },
      500,
    );
  }
});
