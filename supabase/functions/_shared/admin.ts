import { createClient } from 'npm:@supabase/supabase-js@2';

import { jsonResponse } from './cors.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

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

export async function requireAdmin(request: Request) {
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

  return { admin, user, adminUser: adminRow };
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
