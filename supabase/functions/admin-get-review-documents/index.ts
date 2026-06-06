import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

import { createSignedDocumentUrl, requireAdmin } from '../_shared/admin.ts';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';

async function readInput(request: Request) {
  if (request.method === 'GET') {
    const url = new URL(request.url);
    return {
      reviewType: url.searchParams.get('reviewType') ?? '',
      userId: url.searchParams.get('userId') ?? '',
    };
  }

  return await request.json();
}

serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (request.method !== 'GET' && request.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed.' }, 405);
  }

  try {
    const auth = await requireAdmin(request);
    if ('error' in auth) {
      return auth.error;
    }

    const payload = await readInput(request);
    const reviewType = String(payload.reviewType ?? '').trim();
    const userId = String(payload.userId ?? '').trim();

    if (reviewType.length === 0 || userId.length === 0) {
      return jsonResponse({ error: 'Missing reviewType or userId.' }, 400);
    }

    const { admin } = auth;

    if (reviewType === 'identity_verification') {
      const { data: profile, error } = await admin
        .from('profiles')
        .select(
          `
            id,
            email,
            role,
            first_name,
            last_name,
            verification_status,
            identity_license_path,
            identity_selfie_path
          `,
        )
        .eq('id', userId)
        .maybeSingle();

      if (error != null) {
        return jsonResponse({ error: error.message }, 400);
      }

      if (profile == null) {
        return jsonResponse({ error: 'Profile not found.' }, 404);
      }

      const licenseUrl = await createSignedDocumentUrl(
        admin,
        'identity-verification',
        profile.identity_license_path as string | null | undefined,
      );
      const selfieUrl = await createSignedDocumentUrl(
        admin,
        'identity-verification',
        profile.identity_selfie_path as string | null | undefined,
      );

      const documents = [
        {
          key: 'identity_license',
          label: 'Identity License',
          path: profile.identity_license_path,
          signedUrl: licenseUrl,
        },
        {
          key: 'identity_selfie',
          label: 'Identity Selfie',
          path: profile.identity_selfie_path,
          signedUrl: selfieUrl,
        },
      ].filter((item) => item.path != null);

      return jsonResponse({
        reviewType,
        user: {
          id: profile.id,
          email: profile.email,
          role: profile.role,
          firstName: profile.first_name,
          lastName: profile.last_name,
          verificationStatus: profile.verification_status,
        },
        documents,
      });
    }

    if (reviewType === 'instructor_credentials') {
      const { data: instructorProfile, error } = await admin
        .from('instructor_profiles')
        .select(
          `
            profile_id,
            credentials_status,
            instructor_license_path,
            insurance_document_path,
            background_check_path,
            municipal_license_path,
            profile:profiles!instructor_profiles_profile_id_fkey(
              id,
              email,
              role,
              first_name,
              last_name,
              verification_status,
              is_verified
            )
          `,
        )
        .eq('profile_id', userId)
        .maybeSingle();

      if (error != null) {
        return jsonResponse({ error: error.message }, 400);
      }

      if (instructorProfile == null) {
        return jsonResponse({ error: 'Instructor profile not found.' }, 404);
      }

      const instructorLicenseUrl = await createSignedDocumentUrl(
        admin,
        'instructor-credentials',
        instructorProfile.instructor_license_path as string | null | undefined,
      );
      const insuranceUrl = await createSignedDocumentUrl(
        admin,
        'instructor-credentials',
        instructorProfile.insurance_document_path as string | null | undefined,
      );
      const backgroundCheckUrl = await createSignedDocumentUrl(
        admin,
        'instructor-credentials',
        instructorProfile.background_check_path as string | null | undefined,
      );
      const municipalLicenseUrl = await createSignedDocumentUrl(
        admin,
        'instructor-credentials',
        instructorProfile.municipal_license_path as string | null | undefined,
      );

      const profile =
        (instructorProfile.profile as Record<string, unknown> | null) ?? {};

      const documents = [
        {
          key: 'instructor_license',
          label: 'Instructor License',
          path: instructorProfile.instructor_license_path,
          signedUrl: instructorLicenseUrl,
        },
        {
          key: 'insurance_document',
          label: 'Insurance Document',
          path: instructorProfile.insurance_document_path,
          signedUrl: insuranceUrl,
        },
        {
          key: 'background_check',
          label: 'Background Check',
          path: instructorProfile.background_check_path,
          signedUrl: backgroundCheckUrl,
        },
        {
          key: 'municipal_license',
          label: 'Municipal License',
          path: instructorProfile.municipal_license_path,
          signedUrl: municipalLicenseUrl,
        },
      ].filter((item) => item.path != null);

      return jsonResponse({
        reviewType,
        user: {
          id: profile.id,
          email: profile.email,
          role: profile.role,
          firstName: profile.first_name,
          lastName: profile.last_name,
          verificationStatus: profile.verification_status,
          isVerified: profile.is_verified === true,
          credentialsStatus: instructorProfile.credentials_status,
        },
        documents,
      });
    }

    return jsonResponse({ error: 'Unsupported reviewType.' }, 400);
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'Unexpected error.' },
      500,
    );
  }
});
