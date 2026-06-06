import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

import { requireAdmin } from '../_shared/admin.ts';
import { corsHeaders, jsonResponse } from '../_shared/cors.ts';

type Row = Record<string, unknown>;

const completedLessonStatuses = new Set(['completed', 'done', 'finished']);
const cancelledLessonStatuses = new Set(['cancelled', 'canceled']);
const inProgressLessonStatuses = new Set(['active', 'in_progress', 'inprogress']);

function asRow(value: unknown): Row {
  return value != null && typeof value === 'object' ? (value as Row) : {};
}

function stringValue(value: unknown): string | null {
  return typeof value === 'string' && value.trim().length > 0 ? value : null;
}

function numberValue(value: unknown, fallback = 0): number {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  if (typeof value === 'string') {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return fallback;
}

function normalizeLessonStatus(status: unknown): string {
  const normalized = String(status ?? 'scheduled').trim().toLowerCase();
  if (completedLessonStatuses.has(normalized)) return 'completed';
  if (cancelledLessonStatuses.has(normalized)) return 'cancelled';
  if (inProgressLessonStatuses.has(normalized)) return 'in_progress';
  return 'scheduled';
}

function toHours(value: unknown): number {
  const hours = numberValue(value, 1);
  return hours > 0 ? hours : 1;
}

function compareDatesDescending(left: string | null, right: string | null): number {
  const leftMs = left ? Date.parse(left) : 0;
  const rightMs = right ? Date.parse(right) : 0;
  return rightMs - leftMs;
}

function compareDatesAscending(left: string | null, right: string | null): number {
  const leftMs = left ? Date.parse(left) : 0;
  const rightMs = right ? Date.parse(right) : 0;
  return leftMs - rightMs;
}

function normalizeProfile(row: Row) {
  return {
    id: row.id,
    email: row.email,
    phone: row.phone,
    role: row.role,
    firstName: row.first_name,
    lastName: row.last_name,
    city: row.city,
    createdAt: row.created_at,
    verificationStatus: row.verification_status,
    isVerified: row.is_verified === true,
  };
}

function normalizeIdentityReview(row: Row) {
  return {
    id: row.id,
    email: row.email,
    phone: row.phone,
    role: row.role,
    firstName: row.first_name,
    lastName: row.last_name,
    city: row.city,
    createdAt: row.created_at,
    verificationStatus: row.verification_status,
    submittedAt: row.verification_submitted_at,
    reviewStartedAt: row.verification_review_started_at,
    approvedAt: row.verification_approved_at,
    rejectedAt: row.verification_rejected_at,
    rejectionReason: row.verification_rejection_reason,
    reviewNotes: row.verification_review_notes,
    hasLicenseDocument:
      typeof row.identity_license_path === 'string' &&
      row.identity_license_path.trim().length > 0,
    hasSelfieDocument:
      typeof row.identity_selfie_path === 'string' &&
      row.identity_selfie_path.trim().length > 0,
    isVerified: row.is_verified === true,
  };
}

function normalizeCredentialReview(row: Row) {
  const profile = asRow(row.profile);

  return {
    profileId: row.profile_id,
    credentialsStatus: row.credentials_status,
    submittedAt: row.credentials_submitted_at,
    reviewStartedAt: row.credentials_review_started_at,
    approvedAt: row.credentials_approved_at,
    rejectedAt: row.credentials_rejected_at,
    rejectionReason: row.credentials_rejection_reason,
    reviewNotes: row.credentials_review_notes,
    hasInstructorLicense:
      typeof row.instructor_license_path === 'string' &&
      row.instructor_license_path.trim().length > 0,
    hasInsuranceDocument:
      typeof row.insurance_document_path === 'string' &&
      row.insurance_document_path.trim().length > 0,
    hasBackgroundCheck:
      typeof row.background_check_path === 'string' &&
      row.background_check_path.trim().length > 0,
    hasMunicipalLicense:
      typeof row.municipal_license_path === 'string' &&
      row.municipal_license_path.trim().length > 0,
    profile: normalizeProfile(profile),
  };
}

function splitIdentityReviews(rows: Row[]) {
  const collections = {
    pending: [] as ReturnType<typeof normalizeIdentityReview>[],
    approved: [] as ReturnType<typeof normalizeIdentityReview>[],
    rejected: [] as ReturnType<typeof normalizeIdentityReview>[],
  };

  for (const row of rows) {
    const normalized = normalizeIdentityReview(row);
    const status = String(normalized.verificationStatus ?? 'pending');
    if (status === 'approved') {
      collections.approved.push(normalized);
    } else if (status === 'rejected') {
      collections.rejected.push(normalized);
    } else {
      collections.pending.push(normalized);
    }
  }

  collections.pending.sort((a, b) =>
    compareDatesAscending(
      stringValue(a.submittedAt),
      stringValue(b.submittedAt),
    ),
  );
  collections.approved.sort((a, b) =>
    compareDatesDescending(
      stringValue(a.approvedAt),
      stringValue(b.approvedAt),
    ),
  );
  collections.rejected.sort((a, b) =>
    compareDatesDescending(
      stringValue(a.rejectedAt),
      stringValue(b.rejectedAt),
    ),
  );

  return collections;
}

function splitCredentialReviews(rows: Row[]) {
  const collections = {
    pending: [] as ReturnType<typeof normalizeCredentialReview>[],
    approved: [] as ReturnType<typeof normalizeCredentialReview>[],
    rejected: [] as ReturnType<typeof normalizeCredentialReview>[],
  };

  for (const row of rows) {
    const normalized = normalizeCredentialReview(row);
    const status = String(normalized.credentialsStatus ?? 'pending');
    if (status === 'approved') {
      collections.approved.push(normalized);
    } else if (status === 'rejected') {
      collections.rejected.push(normalized);
    } else {
      collections.pending.push(normalized);
    }
  }

  collections.pending.sort((a, b) =>
    compareDatesAscending(
      stringValue(a.submittedAt),
      stringValue(b.submittedAt),
    ),
  );
  collections.approved.sort((a, b) =>
    compareDatesDescending(
      stringValue(a.approvedAt),
      stringValue(b.approvedAt),
    ),
  );
  collections.rejected.sort((a, b) =>
    compareDatesDescending(
      stringValue(a.rejectedAt),
      stringValue(b.rejectedAt),
    ),
  );

  return collections;
}

function normalizeLessonHistory(rows: Row[]) {
  return rows.map((row) => {
    const learner = normalizeProfile(asRow(row.learner));
    const instructorRow = asRow(row.instructor);
    const instructorProfile = normalizeProfile(asRow(instructorRow.user));

    return {
      id: row.id,
      scheduledAt: row.scheduled_at,
      startTime: row.start_time,
      endTime: row.end_time,
      durationHours: toHours(row.duration_hours),
      cost: numberValue(row.cost),
      focus: row.focus,
      pickupLocation: row.pickup_location,
      notes: row.notes,
      status: normalizeLessonStatus(row.status),
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      learnerId: row.learner_id,
      instructorId: row.instructor_id,
      learner,
      instructor: {
        profileId: instructorRow.profile_id ?? row.instructor_id,
        credentialsStatus: instructorRow.credentials_status,
        profile: instructorProfile,
      },
    };
  });
}

function buildInstructorUsage(instructorRows: Row[], lessonHistory: ReturnType<typeof normalizeLessonHistory>) {
  const usageMap = new Map<
    string,
    {
      profileId: string;
      credentialsStatus: string | null;
      defaultRate: number;
      profile: ReturnType<typeof normalizeProfile>;
      totalLessons: number;
      completedLessons: number;
      scheduledLessons: number;
      inProgressLessons: number;
      cancelledLessons: number;
      totalHours: number;
      completedHours: number;
      totalRevenue: number;
      learnerIds: Set<string>;
      lastLessonAt: string | null;
    }
  >();

  for (const row of instructorRows) {
    const profile = normalizeProfile(asRow(row.user));
    const profileId = String(row.profile_id ?? profile.id ?? '');
    if (!profileId) continue;
    usageMap.set(profileId, {
      profileId,
      credentialsStatus: stringValue(row.credentials_status),
      defaultRate: numberValue(row.default_rate),
      profile,
      totalLessons: 0,
      completedLessons: 0,
      scheduledLessons: 0,
      inProgressLessons: 0,
      cancelledLessons: 0,
      totalHours: 0,
      completedHours: 0,
      totalRevenue: 0,
      learnerIds: new Set<string>(),
      lastLessonAt: null,
    });
  }

  for (const lesson of lessonHistory) {
    const instructorId = String(lesson.instructorId ?? '');
    if (!instructorId) continue;
    const bucket = usageMap.get(instructorId);
    if (!bucket) continue;

    bucket.totalLessons += 1;
    bucket.totalHours += lesson.durationHours;
    bucket.totalRevenue += lesson.cost > 0 ? lesson.cost : 0;
    if (stringValue(lesson.learnerId)) {
      bucket.learnerIds.add(String(lesson.learnerId));
    }

    if (
      bucket.lastLessonAt == null ||
      compareDatesDescending(bucket.lastLessonAt, stringValue(lesson.scheduledAt)) > 0
    ) {
      bucket.lastLessonAt = stringValue(lesson.scheduledAt);
    }

    switch (lesson.status) {
      case 'completed':
        bucket.completedLessons += 1;
        bucket.completedHours += lesson.durationHours;
        break;
      case 'cancelled':
        bucket.cancelledLessons += 1;
        break;
      case 'in_progress':
        bucket.inProgressLessons += 1;
        break;
      default:
        bucket.scheduledLessons += 1;
        break;
    }
  }

  return [...usageMap.values()]
    .map((entry) => ({
      profileId: entry.profileId,
      credentialsStatus: entry.credentialsStatus,
      defaultRate: entry.defaultRate,
      totalLessons: entry.totalLessons,
      completedLessons: entry.completedLessons,
      scheduledLessons: entry.scheduledLessons,
      inProgressLessons: entry.inProgressLessons,
      cancelledLessons: entry.cancelledLessons,
      totalHours: entry.totalHours,
      completedHours: entry.completedHours,
      totalRevenue: entry.totalRevenue,
      learnersCount: entry.learnerIds.size,
      lastLessonAt: entry.lastLessonAt,
      profile: entry.profile,
    }))
    .sort((a, b) => {
      if (b.totalLessons !== a.totalLessons) return b.totalLessons - a.totalLessons;
      return compareDatesDescending(
        stringValue(a.lastLessonAt),
        stringValue(b.lastLessonAt),
      );
    });
}

function buildLessonMetrics(
  lessonHistory: ReturnType<typeof normalizeLessonHistory>,
  identityReviews: ReturnType<typeof splitIdentityReviews>,
  instructorReviews: ReturnType<typeof splitCredentialReviews>,
) {
  let completedLessons = 0;
  let scheduledLessons = 0;
  let inProgressLessons = 0;
  let cancelledLessons = 0;
  let totalHours = 0;
  let completedHours = 0;
  let totalRevenue = 0;
  let last30DaysLessons = 0;
  let last30DaysCompletedLessons = 0;
  let last30DaysRevenue = 0;

  const nowMs = Date.now();
  const thirtyDaysAgoMs = nowMs - 30 * 24 * 60 * 60 * 1000;
  const learnerIds = new Set<string>();
  const instructorIds = new Set<string>();

  for (const lesson of lessonHistory) {
    totalHours += lesson.durationHours;
    totalRevenue += lesson.cost > 0 ? lesson.cost : 0;

    if (stringValue(lesson.learnerId)) learnerIds.add(String(lesson.learnerId));
    if (stringValue(lesson.instructorId)) instructorIds.add(String(lesson.instructorId));

    switch (lesson.status) {
      case 'completed':
        completedLessons += 1;
        completedHours += lesson.durationHours;
        break;
      case 'cancelled':
        cancelledLessons += 1;
        break;
      case 'in_progress':
        inProgressLessons += 1;
        break;
      default:
        scheduledLessons += 1;
        break;
    }

    const scheduledAt = stringValue(lesson.scheduledAt);
    const scheduledAtMs = scheduledAt ? Date.parse(scheduledAt) : 0;
    if (scheduledAtMs >= thirtyDaysAgoMs) {
      last30DaysLessons += 1;
      if (lesson.status === 'completed') {
        last30DaysCompletedLessons += 1;
      }
      last30DaysRevenue += lesson.cost > 0 ? lesson.cost : 0;
    }
  }

  return {
    totalLessons: lessonHistory.length,
    completedLessons,
    scheduledLessons,
    inProgressLessons,
    cancelledLessons,
    totalHours,
    completedHours,
    totalRevenue,
    uniqueLearners: learnerIds.size,
    uniqueInstructors: instructorIds.size,
    last30DaysLessons,
    last30DaysCompletedLessons,
    last30DaysRevenue,
    pendingIdentityReviews: identityReviews.pending.length,
    approvedLearners: identityReviews.approved.length,
    rejectedLearners: identityReviews.rejected.length,
    pendingInstructorCredentials: instructorReviews.pending.length,
    approvedInstructors: instructorReviews.approved.length,
    rejectedInstructors: instructorReviews.rejected.length,
  };
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

    const { admin } = auth;

    const { data: identityRows, error: identityError } = await admin
      .from('profiles')
      .select(
        `
          id,
          email,
          phone,
          role,
          first_name,
          last_name,
          city,
          created_at,
          verification_status,
          verification_submitted_at,
          verification_review_started_at,
          verification_approved_at,
          verification_rejected_at,
          verification_rejection_reason,
          verification_review_notes,
          identity_license_path,
          identity_selfie_path,
          is_verified
        `,
      )
      .in('verification_status', ['pending', 'approved', 'rejected']);

    if (identityError != null) {
      return jsonResponse({ error: identityError.message }, 400);
    }

    const { data: credentialRows, error: credentialError } = await admin
      .from('instructor_profiles')
      .select(
        `
          profile_id,
          credentials_status,
          credentials_submitted_at,
          credentials_review_started_at,
          credentials_approved_at,
          credentials_rejected_at,
          credentials_rejection_reason,
          credentials_review_notes,
          instructor_license_path,
          insurance_document_path,
          background_check_path,
          municipal_license_path,
          profile:profiles!instructor_profiles_profile_id_fkey(
            id,
            email,
            phone,
            role,
            first_name,
            last_name,
            city,
            created_at,
            verification_status,
            is_verified
          )
        `,
      )
      .in('credentials_status', ['pending', 'approved', 'rejected']);

    if (credentialError != null) {
      return jsonResponse({ error: credentialError.message }, 400);
    }

    const { data: lessonRows, error: lessonError } = await admin
      .from('lessons')
      .select(
        `
          id,
          scheduled_at,
          start_time,
          end_time,
          duration_hours,
          cost,
          focus,
          pickup_location,
          notes,
          status,
          created_at,
          updated_at,
          learner_id,
          instructor_id,
          learner:profiles(
            id,
            email,
            phone,
            role,
            first_name,
            last_name,
            city,
            created_at,
            verification_status,
            is_verified
          ),
          instructor:instructor_profiles(
            profile_id,
            credentials_status,
            user:profiles!instructor_profiles_profile_id_fkey(
              id,
              email,
              phone,
              role,
              first_name,
              last_name,
              city,
              created_at,
              verification_status,
              is_verified
            )
          )
        `,
      )
      .order('scheduled_at', { ascending: false });

    if (lessonError != null) {
      return jsonResponse({ error: lessonError.message }, 400);
    }

    const { data: instructorRows, error: instructorError } = await admin
      .from('instructor_profiles')
      .select(
        `
          profile_id,
          default_rate,
          credentials_status,
          user:profiles!instructor_profiles_profile_id_fkey(
            id,
            email,
            phone,
            role,
            first_name,
            last_name,
            city,
            created_at,
            verification_status,
            is_verified
          )
        `,
      );

    if (instructorError != null) {
      return jsonResponse({ error: instructorError.message }, 400);
    }

    const identityReviews = splitIdentityReviews((identityRows ?? []) as Row[]);
    const instructorCredentialReviews = splitCredentialReviews(
      (credentialRows ?? []) as Row[],
    );
    const normalizedLessonHistory = normalizeLessonHistory((lessonRows ?? []) as Row[]);
    const instructorUsage = buildInstructorUsage(
      (instructorRows ?? []) as Row[],
      normalizedLessonHistory,
    );
    const lessonMetrics = buildLessonMetrics(
      normalizedLessonHistory,
      identityReviews,
      instructorCredentialReviews,
    );

    return jsonResponse({
      identityReviews,
      instructorCredentialReviews,
      lessonHistory: normalizedLessonHistory.slice(0, 200),
      instructorUsage,
      lessonMetrics,
    });
  } catch (error) {
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'Unexpected error.' },
      500,
    );
  }
});
