import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'npm:@supabase/supabase-js@2';

import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { sha256Hex } from '../_shared/hash.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const NON_INSTRUCTOR_ACCOUNT_MESSAGE =
  'This email is already registered for a learner or guardian account. Use a separate instructor email or contact Drive Tutor support.';
const PROFILE_SELECT =
  'email, role, first_name, last_name, phone, age, gender, languages, licence_number, licence_expiry, onboarding_stage';
const INSTRUCTOR_PROFILE_SELECT =
  'bio, years_of_experience, vehicles, offerings, offering_rates, pickup_preference, preferred_locations, credentials_status';

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

async function authenticatedUser(request: Request) {
  const authHeader = request.headers.get('authorization') ?? '';
  if (!authHeader.toLowerCase().startsWith('bearer ')) return null;

  const token = authHeader.slice('bearer '.length).trim();
  if (token.length === 0) return null;

  const { data, error } = await admin.auth.getUser(token);
  if (error != null || data.user == null) return null;
  return data.user;
}

async function prepareInstructorProfile(authUserId: string, email: string) {
  const { data: existingProfile, error: existingProfileError } = await admin
    .from('profiles')
    .select('id, role')
    .eq('id', authUserId)
    .maybeSingle();

  if (existingProfileError != null) {
    return { error: existingProfileError.message, status: 500 };
  }

  if (existingProfile?.role != null && existingProfile.role !== 'instructor') {
    return { error: NON_INSTRUCTOR_ACCOUNT_MESSAGE, status: 403 };
  }

  if (existingProfile == null) {
    const { error: insertProfileError } = await admin.from('profiles').insert({
      id: authUserId,
      email,
      role: 'instructor',
      onboarding_stage: 'role_selected',
      is_verified: false,
    });

    if (insertProfileError != null) {
      return { error: insertProfileError.message, status: 500 };
    }
  } else if (existingProfile.role == null) {
    const { data: learnerProfile, error: learnerProfileError } = await admin
      .from('learner_profiles')
      .select('profile_id')
      .eq('profile_id', authUserId)
      .maybeSingle();

    if (learnerProfileError != null) {
      return { error: learnerProfileError.message, status: 500 };
    }
    if (learnerProfile != null) {
      return { error: NON_INSTRUCTOR_ACCOUNT_MESSAGE, status: 403 };
    }

    const { error: deleteBlankProfileError } = await admin
      .from('profiles')
      .delete()
      .eq('id', authUserId)
      .is('role', null);

    if (deleteBlankProfileError != null) {
      return { error: deleteBlankProfileError.message, status: 500 };
    }

    const { error: insertProfileError } = await admin.from('profiles').insert({
      id: authUserId,
      email,
      role: 'instructor',
      onboarding_stage: 'role_selected',
      is_verified: false,
    });

    if (insertProfileError != null) {
      return { error: insertProfileError.message, status: 500 };
    }
  } else {
    const { error: emailUpdateError } = await admin
      .from('profiles')
      .update({ email })
      .eq('id', authUserId);

    if (emailUpdateError != null) {
      return { error: emailUpdateError.message, status: 500 };
    }
  }

  const { data: existingInstructorProfile, error: instructorFetchError } =
    await admin
      .from('instructor_profiles')
      .select('credentials_status')
      .eq('profile_id', authUserId)
      .maybeSingle();

  if (instructorFetchError != null) {
    return { error: instructorFetchError.message, status: 500 };
  }

  const { error: instructorUpsertError } = await admin
    .from('instructor_profiles')
    .upsert({
      profile_id: authUserId,
      credentials_status:
        existingInstructorProfile?.credentials_status ?? 'not_started',
    }, { onConflict: 'profile_id' });

  if (instructorUpsertError != null) {
    return { error: instructorUpsertError.message, status: 500 };
  }

  const { data: profile, error: profileError } = await admin
    .from('profiles')
    .select(PROFILE_SELECT)
    .eq('id', authUserId)
    .maybeSingle();

  if (profileError != null) {
    return { error: profileError.message, status: 500 };
  }
  if (profile == null || profile.role !== 'instructor') {
    return { error: 'Unable to prepare this instructor account.', status: 500 };
  }

  const { data: instructorProfile, error: instructorProfileError } = await admin
    .from('instructor_profiles')
    .select(INSTRUCTOR_PROFILE_SELECT)
    .eq('profile_id', authUserId)
    .maybeSingle();

  if (instructorProfileError != null) {
    return { error: instructorProfileError.message, status: 500 };
  }

  return { profile, instructorProfile };
}

serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const payload = await request.json();
    const authUserId = String(payload.authUserId ?? '').trim();
    const email = String(payload.email ?? '').trim().toLowerCase();
    const flowToken = String(payload.flowToken ?? '').trim();
    const action = String(payload.action ?? '').trim();
    const role = String(payload.role ?? '').trim().toLowerCase();

    if (authUserId.length === 0 || email.length === 0) {
      return jsonResponse(
        { error: 'Missing authUserId or email.' },
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

    if (action === 'prepareInstructorProfile') {
      const currentUser = await authenticatedUser(request);
      if (currentUser?.id !== authUserId) {
        return jsonResponse({ error: 'Unauthorized.' }, 401);
      }

      const result = await prepareInstructorProfile(authUserId, email);
      if ('error' in result) {
        return jsonResponse({ error: result.error }, result.status);
      }

      return jsonResponse({
        success: true,
        profile: result.profile,
        instructorProfile: result.instructorProfile,
      });
    }

    if (flowToken.length === 0) {
      return jsonResponse({ error: 'Missing flowToken.' }, 400);
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

    if (role === 'instructor') {
      const result = await prepareInstructorProfile(authUserId, email);
      if ('error' in result) {
        return jsonResponse({ error: result.error }, result.status);
      }
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
