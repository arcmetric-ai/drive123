import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient } from 'npm:@supabase/supabase-js@2';

import { corsHeaders, jsonResponse } from '../_shared/cors.ts';
import { sha256Hex } from '../_shared/hash.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const NON_INSTRUCTOR_ACCOUNT_MESSAGE =
  'This email is already registered for a learner or guardian account. Use a separate instructor email or contact Drive Tutor support.';
const PROFILE_SELECT =
  'email, role, first_name, last_name, phone, age, gender, languages, licence_number, licence_expiry, city, onboarding_stage';
const INSTRUCTOR_PROFILE_SELECT =
  'bio, years_of_experience, vehicles, offerings, offering_rates, pickup_preference, preferred_locations, credentials_status';
const AGREEMENT_KEYS = [
  'terms-and-conditions',
  'privacy-policy',
  'data-consent-policy',
  'instructor-verification-consent',
];

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

function stringValue(value: unknown) {
  return typeof value === 'string' ? value.trim() : '';
}

function nullableString(value: unknown) {
  const cleaned = stringValue(value);
  return cleaned.length > 0 ? cleaned : null;
}

function numberValue(value: unknown) {
  const parsed = typeof value === 'number'
    ? value
    : Number.parseFloat(String(value ?? '').trim());
  return Number.isFinite(parsed) ? parsed : null;
}

function stringArray(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => stringValue(item))
    .filter((item) => item.length > 0);
}

async function saveInstructorQuestionnaire(
  authUserId: string,
  email: string,
  payload: Record<string, unknown>,
) {
  const prepared = await prepareInstructorProfile(authUserId, email);
  if ('error' in prepared) return prepared;

  const profile = payload.profile && typeof payload.profile === 'object'
    ? payload.profile as Record<string, unknown>
    : {};
  const instructor = payload.instructor && typeof payload.instructor === 'object'
    ? payload.instructor as Record<string, unknown>
    : {};

  const licenceNumber = stringValue(profile.licenceNumber).toUpperCase();
  const operatingCity = stringValue(profile.city || instructor.serviceAreaCity);
  const languages = stringArray(profile.languages);
  const offerings = stringArray(instructor.offerings);
  const offeringRates = instructor.offeringRates &&
      typeof instructor.offeringRates === 'object' &&
      !Array.isArray(instructor.offeringRates)
    ? instructor.offeringRates
    : {};

  const { error: profileError } = await admin
    .from('profiles')
    .update({
      email,
      first_name: stringValue(profile.firstName),
      last_name: stringValue(profile.lastName),
      phone: nullableString(profile.phone),
      age: numberValue(profile.age),
      gender: stringValue(profile.gender),
      languages,
      licence_number: licenceNumber,
      licence_expiry: nullableString(profile.licenceExpiry),
      city: nullableString(operatingCity),
      onboarding_stage: 'questionnaire_complete',
      is_verified: false,
    })
    .eq('id', authUserId)
    .eq('role', 'instructor');

  if (profileError != null) {
    return { error: profileError.message, status: 500 };
  }

  const pickupPreference = instructor.pickupPreference !== false;
  const preferredLocations = pickupPreference
    ? null
    : Array.isArray(instructor.preferredLocations)
      ? instructor.preferredLocations
      : [];
  const defaultRate = numberValue(instructor.defaultRate);

  const { data: existingInstructorProfile, error: instructorFetchError } =
    await admin
      .from('instructor_profiles')
      .select('credentials_status')
      .eq('profile_id', authUserId)
      .maybeSingle();

  if (instructorFetchError != null) {
    return { error: instructorFetchError.message, status: 500 };
  }

  const { error: instructorError } = await admin
    .from('instructor_profiles')
    .upsert({
      profile_id: authUserId,
      bio: nullableString(instructor.bio),
      years_of_experience: numberValue(instructor.yearsOfExperience),
      vehicles: Array.isArray(instructor.vehicles) ? instructor.vehicles : [],
      offerings,
      offering_rates: offeringRates,
      default_rate: defaultRate,
      pickup_preference: pickupPreference,
      preferred_locations: preferredLocations,
      credentials_status:
        existingInstructorProfile?.credentials_status ?? 'not_started',
    }, { onConflict: 'profile_id' });

  if (instructorError != null) {
    return { error: instructorError.message, status: 500 };
  }

  const agreementVersion = stringValue(payload.agreementVersion) || '2026-06-24';
  const { data: existingAgreements, error: agreementFetchError } = await admin
    .from('user_agreements')
    .select('agreement_key')
    .eq('profile_id', authUserId)
    .eq('agreement_version', agreementVersion)
    .in('agreement_key', AGREEMENT_KEYS);

  if (agreementFetchError != null) {
    return { error: agreementFetchError.message, status: 500 };
  }

  const existingKeys = new Set(
    (existingAgreements ?? []).map((row) => String(row.agreement_key)),
  );
  const now = new Date().toISOString();
  const agreements = AGREEMENT_KEYS
    .filter((agreementKey) => !existingKeys.has(agreementKey))
    .map((agreementKey) => ({
      profile_id: authUserId,
      agreement_key: agreementKey,
      agreement_version: agreementVersion,
      accepted_at: now,
      policy_url: `https://www.drivetutor.ca/${agreementKey}`,
      source: 'website_instructor_questionnaire',
      role: 'instructor',
      metadata: { source: 'website_instructor_questionnaire' },
    }));

  if (agreements.length > 0) {
    const { error: agreementError } = await admin
      .from('user_agreements')
      .insert(agreements);

    if (agreementError != null) {
      return { error: agreementError.message, status: 500 };
    }
  }

  return await prepareInstructorProfile(authUserId, email);
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

    if (action === 'saveInstructorQuestionnaire') {
      const currentUser = await authenticatedUser(request);
      if (currentUser?.id !== authUserId) {
        return jsonResponse({ error: 'Unauthorized.' }, 401);
      }

      const result = await saveInstructorQuestionnaire(
        authUserId,
        email,
        payload,
      );
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
