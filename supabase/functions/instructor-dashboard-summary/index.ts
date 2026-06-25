import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';

import { corsHeaders, jsonResponse } from '../_shared/cors.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

type JsonMap = Record<string, unknown>;

type BillingPlan = {
  plan_key: string;
  display_name: string;
  billing_interval: 'day' | 'month' | 'year';
};

type Entitlement = {
  plan_key: string;
  status: string;
  access_expires_at: string;
  current_period_end: string | null;
  cancel_at_period_end: boolean | null;
};

type LessonRow = {
  id: string;
  status: string | null;
  focus: string | null;
  scheduled_at: string | null;
  ended_at?: string | null;
  updated_at: string | null;
  pickup_location: string | null;
};

type RequestRow = {
  id: string;
  status: string | null;
  focus: string | null;
  created_at: string | null;
  requested_city?: string | null;
};

const defaultMunicipalLicenseRequiredCities = [
  'toronto',
  'ottawa',
  'mississauga',
  'brampton',
  'vaughan',
  'markham',
  'barrie',
  'guelph',
  'oshawa',
];
const municipalLicenseNotRequiredCities = new Set([
  'etobicoke',
  'downsview',
  'port union',
]);

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
  },
});

function cleanString(value: unknown) {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function asStringArray(value: unknown) {
  return Array.isArray(value)
    ? value.map((item) => cleanString(item)).filter((item): item is string =>
      Boolean(item)
    )
    : [];
}

function offeringLabel(value: string) {
  const normalized = value.trim().toUpperCase();
  if (normalized === 'PR') return 'Refresher';
  return value.trim();
}

function titleCase(value: string) {
  return value
    .split(/[\s_-]+/)
    .filter(Boolean)
    .map((part) =>
      part.charAt(0).toUpperCase() + part.slice(1).toLowerCase()
    )
    .join(' ');
}

function dateKey(value: string | null | undefined) {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date.toISOString().slice(0, 10);
}

function monthKey(value: string | null | undefined) {
  const key = dateKey(value);
  return key ? key.slice(0, 7) : null;
}

function monthLabel(key: string) {
  const date = new Date(`${key}-01T00:00:00.000Z`);
  return new Intl.DateTimeFormat('en-CA', {
    month: 'short',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(date);
}

function completionDate(row: LessonRow) {
  return row.ended_at ?? row.updated_at ?? row.scheduled_at;
}

function classifyFocus(value: string | null | undefined) {
  const normalized = (value ?? '').toLowerCase();
  if (/\brefresher\b|refresh|practice/.test(normalized)) return 'Refresher';
  if (/\bg\s*2\b|g2/.test(normalized)) return 'G2';
  if (/\bg\b|full\s*g|highway/.test(normalized)) return 'G';
  return 'Other';
}

function nextMonthKeys(count: number) {
  const now = new Date();
  const keys: string[] = [];
  for (let index = count - 1; index >= 0; index -= 1) {
    const date = new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - index, 1),
    );
    keys.push(date.toISOString().slice(0, 7));
  }
  return keys;
}

function daysUntil(value: string | null | undefined) {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  const today = new Date();
  const startToday = Date.UTC(
    today.getUTCFullYear(),
    today.getUTCMonth(),
    today.getUTCDate(),
  );
  const target = Date.UTC(
    date.getUTCFullYear(),
    date.getUTCMonth(),
    date.getUTCDate(),
  );
  return Math.ceil((target - startToday) / 86400000);
}

function expiryStatus(value: string | null | undefined) {
  const remaining = daysUntil(value);
  if (remaining == null) return 'missing';
  if (remaining < 0) return 'expired';
  if (remaining <= 30) return 'expiring_soon';
  return 'valid';
}

function isActiveEntitlement(entitlement: Entitlement | null) {
  if (!entitlement) return false;
  return ['active', 'trialing'].includes(entitlement.status) &&
    new Date(entitlement.access_expires_at).getTime() > Date.now();
}

function parseLocations(value: unknown) {
  const locations = new Set<string>();

  const visit = (entry: unknown) => {
    if (!entry) return;
    if (typeof entry === 'string') {
      const cleaned = entry.trim();
      if (cleaned) locations.add(cleaned);
      return;
    }
    if (Array.isArray(entry)) {
      entry.forEach(visit);
      return;
    }
    if (typeof entry === 'object') {
      const map = entry as JsonMap;
      [
        'city',
        'label',
        'name',
        'area',
        'areaName',
        'address',
        'municipality',
        'location',
        'service_area',
        'serviceArea',
        'service_area_city',
        'serviceAreaCity',
      ]
        .forEach((key) => visit(map[key]));
    }
  };

  visit(value);
  return Array.from(locations);
}

function mergeLocations(...values: unknown[]) {
  const seen = new Set<string>();
  const locations: string[] = [];
  values.flatMap(parseLocations).forEach((location) => {
    const key = location.toLowerCase();
    if (seen.has(key)) return;
    seen.add(key);
    locations.push(location);
  });
  return locations;
}

function instructorServiceAreas(instructor: JsonMap, profile: JsonMap) {
  return mergeLocations(
    profile.city,
    instructor.service_area_city,
    instructor.serviceAreaCity,
    instructor.areas_of_operation,
    instructor.service_area,
    instructor.serviceArea,
    instructor.service_area_area,
    instructor.serviceAreaArea,
    instructor.preferred_locations,
  );
}

function configuredMunicipalCities() {
  const configured = (Deno.env.get('MUNICIPAL_LICENSE_REQUIRED_CITIES') ?? '')
    .split(',')
    .map((city) => city.trim().toLowerCase())
    .filter((city) => city && !municipalLicenseNotRequiredCities.has(city));
  return configured.length ? configured : defaultMunicipalLicenseRequiredCities;
}

function municipalRequirement(serviceAreas: string[]) {
  const requiredCities = configuredMunicipalCities();
  if (!requiredCities.length) {
    return {
      configured: false,
      required: false,
      matchedCities: [] as string[],
    };
  }

  const matchedCities = serviceAreas.filter((area) => {
    const normalized = area.toLowerCase();
    return requiredCities.some((city) => normalized.includes(city));
  });

  return {
    configured: true,
    required: matchedCities.length > 0,
    matchedCities,
  };
}

async function selectWithFallback<T>(
  query: () => PromiseLike<
    { data: T[] | null; error: { message: string } | null }
  >,
  fallback: () => PromiseLike<
    { data: T[] | null; error: { message: string } | null }
  >,
) {
  const result = await query();
  if (!result.error) return result;
  return fallback();
}

async function signedUrl(
  client: SupabaseClient,
  bucket: string,
  path: unknown,
) {
  const cleanPath = cleanString(path);
  if (!cleanPath) return null;
  const { data } = await client.storage.from(bucket).createSignedUrl(
    cleanPath,
    300,
  );
  return data?.signedUrl ?? null;
}

async function authenticatedUser(request: Request) {
  const authHeader = request.headers.get('authorization') ?? '';
  if (!authHeader.toLowerCase().startsWith('bearer ')) return null;
  const token = authHeader.slice('bearer '.length).trim();
  if (token.length === 0) return null;
  const { data, error } = await admin.auth.getUser(token);
  if (error != null || data.user == null) return null;
  return data.user;
}

serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const user = await authenticatedUser(request);
    if (!user) return jsonResponse({ error: 'Unauthorized.' }, 401);

    const [
      profileResult,
      instructorResult,
      plansResult,
      entitlementResult,
      customerResult,
    ] = await Promise.all([
      admin.from('profiles').select('*').eq('id', user.id).maybeSingle(),
      admin.from('instructor_profiles').select('*').eq('profile_id', user.id)
        .maybeSingle(),
      admin.from('instructor_billing_plans').select(
        'plan_key, display_name, billing_interval',
      ).eq('is_active', true),
      admin.from('instructor_billing_entitlements').select(
        'plan_key, status, access_expires_at, current_period_end, cancel_at_period_end',
      ).eq('profile_id', user.id).maybeSingle(),
      admin.from('instructor_stripe_customers').select('stripe_customer_id').eq(
        'profile_id',
        user.id,
      ).maybeSingle(),
    ]);

    const firstError = profileResult.error || instructorResult.error ||
      plansResult.error || entitlementResult.error || customerResult.error;
    if (firstError) return jsonResponse({ error: firstError.message }, 500);

    const profile = (profileResult.data ?? {}) as JsonMap;
    if (profile.role !== 'instructor') {
      return jsonResponse({
        error: 'Only instructor accounts can view this dashboard.',
      }, 403);
    }

    const instructor = (instructorResult.data ?? {}) as JsonMap;
    const plans = (plansResult.data ?? []) as BillingPlan[];
    const entitlement = (entitlementResult.data ?? null) as Entitlement | null;
    const activePlan = plans.find((plan) =>
      plan.plan_key === entitlement?.plan_key
    ) ?? null;
    const hasActivePass = isActiveEntitlement(entitlement);

    const completedLessonsResult = await selectWithFallback<LessonRow>(
      () =>
        admin
          .from('lessons')
          .select(
            'id, status, focus, scheduled_at, ended_at, updated_at, pickup_location',
          )
          .eq('instructor_id', user.id)
          .eq('status', 'completed')
          .order('ended_at', { ascending: false })
          .limit(10000),
      () =>
        admin
          .from('lessons')
          .select('id, status, focus, scheduled_at, updated_at, pickup_location')
          .eq('instructor_id', user.id)
          .eq('status', 'completed')
          .order('updated_at', { ascending: false })
          .limit(10000),
    );
    if (completedLessonsResult.error) {
      return jsonResponse({ error: completedLessonsResult.error.message }, 500);
    }

    const requestsResult = await selectWithFallback<RequestRow>(
      () =>
        admin
          .from('learner_requests')
          .select('id, status, focus, created_at, requested_city')
          .eq('instructor_id', user.id)
          .order('created_at', { ascending: false })
          .limit(10000),
      () =>
        admin
          .from('learner_requests')
          .select('id, status, focus, created_at')
          .eq('instructor_id', user.id)
          .order('created_at', { ascending: false })
          .limit(10000),
    );
    if (requestsResult.error) {
      return jsonResponse({ error: requestsResult.error.message }, 500);
    }

    const lessons = completedLessonsResult.data ?? [];
    const requests = requestsResult.data ?? [];
    const now = new Date();
    const currentMonth = `${now.getUTCFullYear()}-${
      String(now.getUTCMonth() + 1).padStart(2, '0')
    }`;
    const previousDate = new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 1, 1),
    );
    const previousMonth = previousDate.toISOString().slice(0, 7);
    const monthKeys = nextMonthKeys(6);

    const lessonsThisMonth = lessons.filter((row) =>
      monthKey(completionDate(row)) === currentMonth
    );
    const lessonsPreviousMonth = lessons.filter((row) =>
      monthKey(completionDate(row)) === previousMonth
    );
    const lessonTrend = monthKeys.map((key) => ({
      key,
      label: monthLabel(key),
      completed: lessons.filter((row) =>
        monthKey(completionDate(row)) === key
      ).length,
    }));

    const focusLabels = ['G2', 'G', 'Refresher', 'Other'];
    const focusLifetime = focusLabels.map((label) => ({
      label,
      count: lessons.filter((row) => classifyFocus(row.focus) === label)
        .length,
    }));
    const focusThisMonth = focusLabels.map((label) => ({
      label,
      count: lessonsThisMonth.filter((row) =>
        classifyFocus(row.focus) === label
      ).length,
    }));

    const countedRequests = requests.filter((row) => {
      const status = (row.status ?? '').toLowerCase();
      return status !== 'cancelled' && status !== 'removed';
    });
    const acceptedRequests = countedRequests.filter((row) =>
      ['accepted', 'active', 'in_progress'].includes(
        (row.status ?? '').toLowerCase(),
      )
    );
    const pendingRequests = countedRequests.filter((row) =>
      (row.status ?? '').toLowerCase() === 'pending'
    );
    const requestsThisMonth = countedRequests.filter((row) =>
      monthKey(row.created_at) === currentMonth
    );
    const acceptedThisMonth = acceptedRequests.filter((row) =>
      monthKey(row.created_at) === currentMonth
    );
    const acceptanceRate = countedRequests.length
      ? Math.round((acceptedRequests.length / countedRequests.length) * 100)
      : null;

    const cityCounts = new Map<string, number>();
    countedRequests.forEach((row) => {
      const city = cleanString(row.requested_city);
      if (!city) return;
      const label = titleCase(city);
      cityCounts.set(label, (cityCounts.get(label) ?? 0) + 1);
    });
    const topCities = Array.from(cityCounts.entries())
      .map(([city, count]) => ({ city, count }))
      .sort((a, b) => b.count - a.count || a.city.localeCompare(b.city))
      .slice(0, 5);

    const serviceAreas = instructorServiceAreas(instructor, profile);
    const municipal = municipalRequirement(serviceAreas);
    const documentReviewStatus = cleanString(instructor.credentials_status);
    const verificationStatus = cleanString(profile.verification_status);
    const backgroundCheckStatus =
      documentReviewStatus === 'approved' && instructor.background_check_path
        ? 'approved'
        : documentReviewStatus ?? 'not_started';

    const documents = await Promise.all([
      {
        key: 'government_id',
        label: 'G licence',
        status: profile.identity_license_path
          ? verificationStatus ?? 'uploaded'
          : 'missing',
        expiry: null,
        required: true,
        href: await signedUrl(
          admin,
          'identity-verification',
          profile.identity_license_path,
        ),
      },
      {
        key: 'selfie',
        label: 'Selfie verification',
        status: profile.identity_selfie_path
          ? verificationStatus ?? 'uploaded'
          : 'missing',
        expiry: null,
        required: true,
        href: await signedUrl(
          admin,
          'identity-verification',
          profile.identity_selfie_path,
        ),
      },
      {
        key: 'instructor_licence',
        label: 'Instructor licence',
        status: instructor.instructor_license_path
          ? documentReviewStatus ?? 'uploaded'
          : 'missing',
        expiry: cleanString(instructor.instructor_license_expiry) ??
          cleanString(profile.licence_expiry),
        required: true,
        href: await signedUrl(
          admin,
          'instructor-credentials',
          instructor.instructor_license_path,
        ),
      },
      {
        key: 'insurance',
        label: 'Insurance',
        status: instructor.insurance_document_path
          ? documentReviewStatus ?? 'uploaded'
          : 'missing',
        expiry: cleanString(instructor.insurance_expiry) ??
          cleanString(instructor.insurance_document_expiry),
        required: true,
        href: await signedUrl(
          admin,
          'instructor-credentials',
          instructor.insurance_document_path,
        ),
      },
      {
        key: 'municipal_licence',
        label: 'Municipal licence',
        status: instructor.municipal_license_path
          ? documentReviewStatus ?? 'uploaded'
          : municipal.required
          ? 'missing'
          : 'not_required',
        expiry: cleanString(instructor.municipal_license_expiry) ??
          cleanString(instructor.municipal_licence_expiry),
        required: municipal.required,
        href: await signedUrl(
          admin,
          'instructor-credentials',
          instructor.municipal_license_path,
        ),
      },
      {
        key: 'background_check',
        label: 'Background check',
        status: backgroundCheckStatus,
        expiry: null,
        required: true,
        href: await signedUrl(
          admin,
          'instructor-credentials',
          instructor.background_check_path,
        ),
      },
    ]);

    const requiredDocuments = documents.filter((document) =>
      document.required
    );
    const profileQualityItems = [
      {
        label: 'Service areas',
        complete: serviceAreas.length > 0,
        value: serviceAreas.length ? serviceAreas.join(', ') : 'Not set',
      },
      {
        label: 'Rates',
        complete: Boolean(instructor.offering_rates) ||
          Boolean(instructor.default_rate),
        value: instructor.offering_rates
          ? 'Set by lesson focus'
          : instructor.default_rate
          ? 'Default rate set'
          : 'Not set',
      },
      {
        label: 'Languages',
        complete: asStringArray(profile.languages).length > 0,
        value: asStringArray(profile.languages).join(', ') || 'Not set',
      },
      {
        label: 'Vehicle details',
        complete: Boolean(instructor.vehicles),
        value: instructor.vehicles ? 'Saved' : 'Not set',
      },
      {
        label: 'Lesson offerings',
        complete: asStringArray(instructor.offerings).length > 0,
        value: asStringArray(instructor.offerings).map(offeringLabel).join(
          ', ',
        ) || 'Not set',
      },
    ];
    const profileCompletion = Math.round(
      (profileQualityItems.filter((item) => item.complete).length /
        profileQualityItems.length) * 100,
    );
    const readinessChecks = [
      { key: 'pass', label: 'Pass active', complete: hasActivePass },
      {
        key: 'verification',
        label: 'Verification approved',
        complete: verificationStatus === 'approved' ||
          profile.is_verified === true,
      },
      {
        key: 'documents',
        label: 'Required documents approved',
        complete: requiredDocuments.every((document) =>
          document.status === 'approved'
        ),
      },
      {
        key: 'profile',
        label: 'Profile basics complete',
        complete: profileCompletion >= 80,
      },
      {
        key: 'compliance',
        label: 'No expired required documents',
        complete: requiredDocuments.every((document) =>
          !document.expiry || expiryStatus(document.expiry) !== 'expired'
        ),
      },
    ];
    const readinessScore = Math.round(
      (readinessChecks.filter((check) => check.complete).length /
        readinessChecks.length) * 100,
    );
    const nextRequiredUpdate = requiredDocuments
      .filter((document) => document.expiry)
      .sort((a, b) =>
        new Date(a.expiry!).getTime() - new Date(b.expiry!).getTime()
      )[0] ?? null;

    return jsonResponse({
      instructor: {
        name: [
          cleanString(profile.first_name),
          cleanString(profile.last_name),
        ].filter(Boolean).join(' ') || cleanString(profile.email) ||
          'Instructor',
        email: cleanString(profile.email) ?? user.email ?? '',
        phone: cleanString(profile.phone),
      },
      readiness: {
        score: readinessScore,
        status: readinessChecks.every((check) => check.complete)
          ? 'ready'
          : 'action_needed',
        checks: readinessChecks,
      },
      pass: {
        active: hasActivePass,
        status: entitlement?.status ?? 'not_active',
        planKey: activePlan?.plan_key ?? entitlement?.plan_key ?? null,
        billingInterval: activePlan?.billing_interval ?? null,
        planName: activePlan?.display_name ?? 'No active pass',
        renewalOrExpiryDate: entitlement?.current_period_end ??
          entitlement?.access_expires_at ?? null,
        cancelAtPeriodEnd: entitlement?.cancel_at_period_end ?? false,
        stripeCustomerConnected: Boolean(
          (customerResult.data as { stripe_customer_id?: string } | null)
            ?.stripe_customer_id,
        ),
      },
      activity: {
        completedThisMonth: lessonsThisMonth.length,
        completedPreviousMonth: lessonsPreviousMonth.length,
        completedLifetime: lessons.length,
        monthlyTrend: lessonTrend,
        focusThisMonth,
        focusLifetime,
        rowsMayBeLimited: lessons.length >= 10000,
      },
      requests: {
        totalCounted: countedRequests.length,
        totalThisMonth: requestsThisMonth.length,
        acceptedTotal: acceptedRequests.length,
        acceptedThisMonth: acceptedThisMonth.length,
        pending: pendingRequests.length,
        acceptanceRate,
        excludedStatuses: ['cancelled', 'removed'],
        rowsMayBeLimited: requests.length >= 10000,
      },
      serviceAreas: {
        selected: serviceAreas,
        municipalRequirement: municipal,
        topRequestCities: topCities,
      },
      compliance: {
        verificationStatus: verificationStatus ?? 'not_started',
        credentialsStatus: documentReviewStatus ?? 'not_started',
        nextRequiredUpdate,
        documents: documents.map((document) => ({
          ...document,
          expiryStatus: expiryStatus(document.expiry),
        })),
      },
      profileQuality: {
        completion: profileCompletion,
        items: profileQualityItems,
        editableInAppOnly: true,
      },
    });
  } catch (error) {
    return jsonResponse({
      error: error instanceof Error ? error.message : 'Unexpected error.',
    }, 500);
  }
});
