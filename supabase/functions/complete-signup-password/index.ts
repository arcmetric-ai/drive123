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
    const newPassword = String(payload.newPassword ?? '');

    if (
      authUserId.length === 0 ||
      flowToken.length === 0 ||
      newPassword.length === 0
    ) {
      return jsonResponse(
        { error: 'Missing authUserId, flowToken, or newPassword.' },
        400,
      );
    }

    if (newPassword.length < 8) {
      return jsonResponse(
        { error: 'Password must be at least 8 characters.' },
        400,
      );
    }
    if (!/[a-z]/.test(newPassword)) {
      return jsonResponse(
        { error: 'Password must include a lowercase letter.' },
        400,
      );
    }
    if (!/[A-Z]/.test(newPassword)) {
      return jsonResponse(
        { error: 'Password must include an uppercase letter.' },
        400,
      );
    }
    if (!/\d/.test(newPassword)) {
      return jsonResponse(
        { error: 'Password must include a number.' },
        400,
      );
    }
    if (!/[^A-Za-z0-9]/.test(newPassword)) {
      return jsonResponse(
        { error: 'Password must include a symbol.' },
        400,
      );
    }

    const flowTokenHash = await sha256Hex(flowToken);
    const nowIso = new Date().toISOString();
    const { data: flow, error: flowError } = await admin
      .from('signup_flows')
      .select('auth_user_id, completed_at, expires_at')
      .eq('auth_user_id', authUserId)
      .eq('flow_token_hash', flowTokenHash)
      .maybeSingle();

    if (flowError != null) {
      return jsonResponse({ error: flowError.message }, 400);
    }

    if (flow == null) {
      return jsonResponse({ error: 'Signup flow not found or expired.' }, 404);
    }

    if (flow['completed_at'] != null) {
      return jsonResponse({ success: true, alreadyCompleted: true });
    }

    const expiresAt = String(flow['expires_at'] ?? '');
    if (expiresAt.length === 0 || expiresAt <= nowIso) {
      return jsonResponse({ error: 'Signup flow not found or expired.' }, 404);
    }

    const { data, error } = await admin.auth.admin.getUserById(authUserId);
    if (error != null || data.user == null) {
      return jsonResponse({ error: 'Auth user not found.' }, 404);
    }

    const emailConfirmedAt =
      (data.user as { email_confirmed_at?: string | null }).email_confirmed_at;
    if (emailConfirmedAt == null) {
      return jsonResponse({ error: 'Email is not confirmed yet.' }, 400);
    }

    const { error: updateError } = await admin.auth.admin.updateUserById(
      authUserId,
      { password: newPassword },
    );
    if (updateError != null) {
      return jsonResponse({ error: updateError.message }, 400);
    }

    await admin.from('signup_flows').update({
      'confirmed_at': emailConfirmedAt,
      'completed_at': new Date().toISOString(),
    }).eq('auth_user_id', authUserId);

    return jsonResponse({
      'success': true,
      'email': data.user.email,
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
