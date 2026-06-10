class IdentityVerificationState {
  const IdentityVerificationState({
    required this.userId,
    required this.role,
    required this.firstName,
    required this.createdAt,
    required this.isVerified,
    this.verificationStatus,
    this.verificationSubmittedAt,
    this.verificationReviewStartedAt,
    this.verificationApprovedAt,
    this.identityLicensePath,
    this.identitySelfiePath,
    this.guardianIdentityLicensePath,
    this.guardianIdentitySelfiePath,
    this.guardianConsentSubmittedAt,
    this.age,
    this.onboardingStage,
  });

  factory IdentityVerificationState.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    String? stringOrNull(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        final trimmed = value.trim();
        return trimmed.isEmpty ? null : trimmed;
      }
      return value.toString();
    }

    return IdentityVerificationState(
      userId: json['id'] as String,
      role: stringOrNull(json['role']) ?? 'learner',
      firstName: stringOrNull(json['first_name']),
      createdAt: parseDate(json['created_at']),
      isVerified: json['is_verified'] as bool? ?? false,
      verificationStatus: stringOrNull(json['verification_status']),
      verificationSubmittedAt: parseDate(json['verification_submitted_at']),
      verificationReviewStartedAt:
          parseDate(json['verification_review_started_at']),
      verificationApprovedAt: parseDate(json['verification_approved_at']),
      identityLicensePath: stringOrNull(json['identity_license_path']),
      identitySelfiePath: stringOrNull(json['identity_selfie_path']),
      guardianIdentityLicensePath:
          stringOrNull(json['guardian_identity_license_path']),
      guardianIdentitySelfiePath:
          stringOrNull(json['guardian_identity_selfie_path']),
      guardianConsentSubmittedAt:
          parseDate(json['guardian_consent_submitted_at']),
      age: json['age'] is int
          ? json['age'] as int
          : int.tryParse(stringOrNull(json['age']) ?? ''),
      onboardingStage: stringOrNull(json['onboarding_stage']),
    );
  }

  final String userId;
  final String role;
  final String? firstName;
  final DateTime? createdAt;
  final bool isVerified;
  final String? verificationStatus;
  final DateTime? verificationSubmittedAt;
  final DateTime? verificationReviewStartedAt;
  final DateTime? verificationApprovedAt;
  final String? identityLicensePath;
  final String? identitySelfiePath;
  final String? guardianIdentityLicensePath;
  final String? guardianIdentitySelfiePath;
  final DateTime? guardianConsentSubmittedAt;
  final int? age;
  final String? onboardingStage;

  bool get requiresGuardianConsent => age == 16 || age == 17;

  bool get hasIdentityDocuments =>
      identityLicensePath?.trim().isNotEmpty == true &&
      identitySelfiePath?.trim().isNotEmpty == true;

  bool get hasGuardianDocuments =>
      guardianIdentityLicensePath?.trim().isNotEmpty == true &&
      guardianIdentitySelfiePath?.trim().isNotEmpty == true;

  bool get hasRequiredIdentityDocuments =>
      hasIdentityDocuments &&
      (!requiresGuardianConsent || hasGuardianDocuments);

  bool get isApproved =>
      isVerified ||
      verificationStatus == 'approved' ||
      verificationApprovedAt != null;

  bool get isPendingReview =>
      !isApproved &&
      (verificationStatus == 'pending' || verificationSubmittedAt != null);
}
