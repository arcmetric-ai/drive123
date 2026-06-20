import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

import { requireAdmin } from '../_shared/admin.ts';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const passwordRecoveryRedirect = 'https://www.drivetutor.ca/auth-redirect';

serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405);
  }

  try {
    const contentLength = Number(request.headers.get('content-length') ?? '0');
    if (contentLength > 4096) {
      return jsonResponse({ error: 'Request is too large.' }, 413);
    }

    const auth = await requireAdmin(request);
    if ('error' in auth) return auth.error;

    const payload = await request.json();
    const action = String(payload?.action ?? '').trim();
    const targetUserId = String(payload?.targetUserId ?? '').trim();
    if (!uuidPattern.test(targetUserId)) {
      return jsonResponse({ error: 'A valid targetUserId is required.' }, 400);
    }
    if (!['send_password_recovery', 'revoke_sessions'].includes(action)) {
      return jsonResponse({ error: 'Unsupported account action.' }, 400);
    }
    if (targetUserId === auth.user.id) {
      return jsonResponse(
        { error: 'Use a second administrator account for actions on your own account.' },
        409,
      );
    }

    const { data: targetResult, error: targetError } =
      await auth.admin.auth.admin.getUserById(targetUserId);
    if (targetError != null || targetResult.user == null) {
      return jsonResponse({ error: 'Target user was not found.' }, 404);
    }

    let auditAction: 'password_recovery_sent' | 'sessions_revoked';
    let sessionsRevoked: number | null = null;
    if (action === 'send_password_recovery') {
      const email = targetResult.user.email;
      if (email == null || email.trim().length === 0) {
        return jsonResponse({ error: 'Target account has no email address.' }, 409);
      }
      const { error } = await auth.admin.auth.resetPasswordForEmail(email, {
        redirectTo: passwordRecoveryRedirect,
      });
      if (error != null) throw error;
      auditAction = 'password_recovery_sent';
    } else {
      const { data, error } = await auth.admin.rpc('admin_revoke_user_sessions', {
        p_target_user_id: targetUserId,
      });
      if (error != null) throw error;
      sessionsRevoked = Number(data ?? 0);
      auditAction = 'sessions_revoked';
    }

    const { error: auditError } = await auth.admin
      .from('admin_account_actions')
      .insert({
        admin_user_id: auth.user.id,
        target_user_id: targetUserId,
        action: auditAction,
      });
    if (auditError != null) throw auditError;

    return jsonResponse({
      ok: true,
      action,
      targetUserId,
      ...(sessionsRevoked == null ? {} : { sessionsRevoked }),
    });
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'Unexpected error.' },
      500,
    );
  }
});
