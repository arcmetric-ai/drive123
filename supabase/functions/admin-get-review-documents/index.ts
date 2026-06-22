import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

import { createSignedDocumentUrl, requireAdmin } from '../_shared/admin.ts';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';

const documentLabels: Record<string, string> = {
  identity_license: 'Identity Licence',
  guardian_identity_license: 'Guardian Government ID',
  instructor_license: 'Instructor Licence',
  insurance_document: '6D Insurance Document',
  background_check: 'Background Check',
  municipal_license: 'Municipal Licence',
};

const requireDocumentScan =
  String(Deno.env.get('REQUIRE_DOCUMENT_SCAN') ?? 'false').toLowerCase() !==
  'false';

async function loadDocumentVersions(
  admin: any,
  userId: string,
  documentTypes: string[],
) {
  const { data, error } = await admin
    .from('verification_document_versions')
    .select(
      'id, document_type, version_number, storage_bucket, storage_path, original_file_name, mime_type, size_bytes, sha256_hex, expires_at, uploaded_at',
    )
    .eq('owner_user_id', userId)
    .in('document_type', documentTypes)
    .order('uploaded_at', { ascending: false });
  if (error != null) throw new Error(error.message);

  const documentIds = (data ?? []).map(
    (document: Record<string, unknown>) => String(document.id),
  );
  const latestScanByDocument = new Map<string, Record<string, unknown>>();
  if (documentIds.length > 0) {
    const { data: scanEvents, error: scanError } = await admin
      .from('verification_document_scan_events')
      .select('document_version_id, status, provider, engine_version, threat_name, created_at')
      .in('document_version_id', documentIds)
      .order('created_at', { ascending: false });
    if (scanError != null) throw new Error(scanError.message);
    for (const scan of scanEvents ?? []) {
      const documentId = String(scan.document_version_id);
      if (!latestScanByDocument.has(documentId)) {
        latestScanByDocument.set(documentId, scan);
      }
    }
  }

  return await Promise.all(
    (data ?? []).map(async (document: Record<string, unknown>) => {
      const scan = latestScanByDocument.get(String(document.id));
      const scanStatus = requireDocumentScan
        ? String(scan?.status ?? 'pending')
        : 'manual_review_allowed';
      return {
        id: document.id,
        key: document.document_type,
        label: documentLabels[String(document.document_type)] ?? 'Document',
        version: document.version_number,
        path: document.storage_path,
        originalFileName: document.original_file_name,
        mimeType: document.mime_type,
        sizeBytes: document.size_bytes,
        sha256: document.sha256_hex,
        expiresAt: document.expires_at,
        uploadedAt: document.uploaded_at,
        scanStatus,
        scanProvider: scan?.provider,
        scanThreatName: scan?.threat_name,
        signedUrl: scanStatus === 'clean' || !requireDocumentScan
          ? await createSignedDocumentUrl(
            admin,
            String(document.storage_bucket),
            String(document.storage_path),
          )
          : null,
      };
    }),
  );
}

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
            identity_selfie_path,
            guardian_identity_license_path,
            guardian_identity_selfie_path,
            guardian_consent_submitted_at
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

      const selfieUrl = await createSignedDocumentUrl(
        admin,
        'identity-verification',
        profile.identity_selfie_path as string | null | undefined,
      );
      const guardianSelfieUrl = await createSignedDocumentUrl(
        admin,
        'identity-verification',
        profile.guardian_identity_selfie_path as string | null | undefined,
      );

      const documentVersions = await loadDocumentVersions(admin, userId, [
        'identity_license',
        'guardian_identity_license',
      ]);
      const documents = [
        ...documentVersions,
        {
          key: 'identity_selfie',
          label: 'Identity Selfie',
          path: profile.identity_selfie_path,
          scanStatus: requireDocumentScan
            ? 'manual_review_required'
            : 'manual_review_allowed',
          signedUrl: selfieUrl,
        },
        {
          key: 'guardian_identity_selfie',
          label: 'Guardian Verification Selfie',
          path: profile.guardian_identity_selfie_path,
          scanStatus: requireDocumentScan
            ? 'manual_review_required'
            : 'manual_review_allowed',
          signedUrl: guardianSelfieUrl,
        },
      ].filter((item) => item.path != null);

      return jsonResponse({
        reviewType,
        scanningRequired: requireDocumentScan,
        user: {
          id: profile.id,
          email: profile.email,
          role: profile.role,
          firstName: profile.first_name,
          lastName: profile.last_name,
          verificationStatus: profile.verification_status,
          guardianConsentSubmittedAt: profile.guardian_consent_submitted_at,
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
            instructor_license_expires_at,
            insurance_document_path,
            insurance_document_expires_at,
            background_check_path,
            municipal_license_path,
            municipal_license_expires_at,
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

      const rawProfile = instructorProfile.profile as unknown;
      const profile = Array.isArray(rawProfile)
        ? ((rawProfile[0] as Record<string, unknown> | undefined) ?? {})
        : ((rawProfile as Record<string, unknown> | null) ?? {});

      const documents = await loadDocumentVersions(admin, userId, [
        'instructor_license',
        'insurance_document',
        'background_check',
        'municipal_license',
      ]);

      return jsonResponse({
        reviewType,
        scanningRequired: requireDocumentScan,
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
