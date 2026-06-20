import {
  createClient,
  type SupabaseClient,
  type User,
} from 'npm:@supabase/supabase-js@2';

import { jsonResponse } from './cors.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function sessionIdFromAuthorization(authorization: string) {
  try {
    const token = authorization.replace(/^Bearer\s+/i, '');
    const encodedPayload = token.split('.')[1];
    if (encodedPayload == null) return null;
    const normalized = encodedPayload.replaceAll('-', '+').replaceAll('_', '/');
    const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '=');
    const payload = JSON.parse(atob(padded)) as Record<string, unknown>;
    const sessionId = String(payload.session_id ?? '');
    return uuidPattern.test(sessionId) ? sessionId : null;
  } catch (_) {
    return null;
  }
}

function createServiceClient() {
  return createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
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

type AdminAuthResult =
  | {
    error: Response;
  }
  | {
    admin: SupabaseClient;
    user: User;
    adminUser: { user_id: string; email: string | null };
  };

export async function requireAdmin(request: Request): Promise<AdminAuthResult> {
  const authorization = request.headers.get('Authorization');
  if (authorization == null || authorization.trim().length === 0) {
    return {
      error: jsonResponse({ error: 'Missing Authorization header.' }, 401),
    };
  }

  const requestClient = createRequestClient(request);
  const {
    data: { user },
    error: userError,
  } = await requestClient.auth.getUser();

  if (userError != null || user == null) {
    return {
      error: jsonResponse({ error: 'Unauthorized.' }, 401),
    };
  }

  const admin = createServiceClient();
  const sessionId = sessionIdFromAuthorization(authorization);
  if (sessionId == null) {
    return {
      error: jsonResponse({ error: 'Session identifier is missing.' }, 401),
    };
  }
  const { data: sessionActive, error: sessionError } = await admin.rpc(
    'is_auth_session_active',
    { p_session_id: sessionId },
  );
  if (sessionError != null || sessionActive !== true) {
    return {
      error: jsonResponse({ error: 'Session has been revoked.' }, 401),
    };
  }
  const { data: adminRow, error: adminError } = await admin
    .from('admin_users')
    .select('user_id, email')
    .eq('user_id', user.id)
    .maybeSingle();

  if (adminError != null) {
    return {
      error: jsonResponse({ error: adminError.message }, 500),
    };
  }

  if (adminRow == null) {
    return {
      error: jsonResponse({ error: 'Forbidden.' }, 403),
    };
  }

  return {
    admin,
    user,
    adminUser: {
      user_id: String(adminRow.user_id),
      email: adminRow.email == null ? null : String(adminRow.email),
    },
  };
}

export async function createSignedDocumentUrl(
  admin: ReturnType<typeof createServiceClient>,
  bucket: string,
  path: string | null | undefined,
  expiresInSeconds = 60 * 15,
) {
  const normalizedPath = path?.trim();
  if (normalizedPath == null || normalizedPath.length === 0) {
    return null;
  }

  const { data, error } = await admin.storage
    .from(bucket)
    .createSignedUrl(normalizedPath, expiresInSeconds);

  if (error != null) {
    throw new Error(error.message);
  }

  return data.signedUrl;
}
