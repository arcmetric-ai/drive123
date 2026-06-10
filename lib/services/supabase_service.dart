import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:convert';
import '../constants/app_routes.dart';
import '../models/identity_verification_state.dart';
import '../models/instructor_billing.dart';
import '../models/instructor_document_type.dart';
import '../models/learner_onboarding_draft.dart';
import '../models/signup_flow_state.dart';
import '../services/launch_preferences.dart';
import '../models/user_model.dart';
import '../models/instructor_model.dart';
import '../models/lesson_model.dart';

class AccountAlreadyExistsException implements Exception {
  const AccountAlreadyExistsException(this.email);

  final String email;

  @override
  String toString() => 'An account already exists for $email.';
}

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;
  static const int learnerSkillCatalogSize = 8;
  static const Set<String> _supportedRoles = {'learner', 'instructor'};
  static const String _identityVerificationBucket = 'identity-verification';
  static const String _instructorCredentialsBucket = 'instructor-credentials';
  static const String _baseAppUrl = 'https://www.drivetutor.ca';
  static const String _authRedirectUrl = '$_baseAppUrl/auth-redirect';
  static const String _signUpRedirectUrl = _authRedirectUrl;
  static const String onboardingStageRoleSelected = 'role_selected';
  static const String onboardingStageVerificationPending =
      'verification_pending';
  static const String onboardingStageQuestionnaireComplete =
      'questionnaire_complete';

  static String? _normalizeRole(dynamic role) {
    if (role is! String) return null;
    final normalized = role.trim().toLowerCase();
    if (_supportedRoles.contains(normalized)) return normalized;
    return null;
  }

  static String _normalizeLearnerAccountType(dynamic value) {
    if (value is String && value.trim().toLowerCase() == 'guardian') {
      return 'guardian';
    }
    return 'learner';
  }

  // Auth Methods
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
      },
    );
    final user = response.user;
    if (user != null) {
      try {
        await _client.from('profiles').upsert({
          'id': user.id,
          'email': email,
          'phone': phone,
          'first_name': firstName,
          'last_name': lastName,
        });
      } catch (e) {
        // ignore, profile trigger will still insert minimal row
        print('Warning: unable to upsert profile after signup: $e');
      }
    }
    return response;
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  static Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user ?? _client.auth.currentUser;
    if (user != null) {
      try {
        await _client.from('profiles').upsert({
          'id': user.id,
          'email': user.email ?? email,
        }, onConflict: 'id');
      } catch (e) {
        print('Warning: unable to upsert profile after signup: $e');
      }
    }

    return response;
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  static Future<void> requestPasswordRecoveryCode({
    required String email,
  }) async {
    await _client.auth.resetPasswordForEmail(email.trim().toLowerCase());
  }

  static Future<SignupFlowState> startSignUpFlow({
    required String email,
    String role = 'learner',
    String learnerAccountType = 'learner',
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final tempPassword = _generateTemporaryPassword();
    final response = await _client.auth.signUp(
      email: normalizedEmail,
      password: tempPassword,
      emailRedirectTo: _signUpRedirectUrl,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Unable to start sign up. Please try again.');
    }

    final flowState = SignupFlowState(
      email: normalizedEmail,
      authUserId: user.id,
      flowToken: _generateFlowToken(),
      role: _normalizeRole(role) ?? 'learner',
      learnerAccountType: _normalizeLearnerAccountType(learnerAccountType),
    );

    try {
      await _client.functions.invoke(
        'begin-signup-flow',
        body: flowState.toMap(),
      );
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('auth user not found') ||
          message.contains('user already registered')) {
        throw AccountAlreadyExistsException(normalizedEmail);
      }
      rethrow;
    }

    return flowState;
  }

  static Future<bool> checkSignUpConfirmation({
    required SignupFlowState flowState,
  }) async {
    final response = await _client.functions.invoke(
      'check-signup-confirmation',
      body: flowState.toMap(),
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Unexpected signup confirmation response.');
    }
    return data['confirmed'] == true;
  }

  static Future<void> completeSignUpPassword({
    required SignupFlowState flowState,
    required String newPassword,
  }) async {
    await _client.functions.invoke(
      'complete-signup-password',
      body: {
        ...flowState.toMap(),
        'newPassword': newPassword,
      },
    );
  }

  static Future<AuthResponse> verifySignUpCode({
    required String email,
    required String token,
  }) async {
    final response = await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );

    final user = response.user ?? _client.auth.currentUser;
    if (user != null) {
      try {
        await _client.from('profiles').upsert({
          'id': user.id,
          'email': user.email ?? email,
        }, onConflict: 'id');
      } catch (e) {
        print('Warning: unable to upsert profile after signup verify: $e');
      }
    }

    return response;
  }

  static Future<AuthResponse> verifyPasswordRecoveryCode({
    required String email,
    required String token,
  }) async {
    return _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.recovery,
    );
  }

  static Future<void> assignUserRole({
    required String userId,
    required String role,
    String learnerAccountType = 'learner',
  }) async {
    final normalizedRole = _normalizeRole(role);
    if (normalizedRole == null) {
      throw ArgumentError('Unsupported role "$role"');
    }

    await _client.from('profiles').upsert(
      {
        'id': userId,
        'role': normalizedRole,
        'onboarding_stage': onboardingStageRoleSelected,
      },
      onConflict: 'id',
    );

    if (normalizedRole == 'instructor') {
      await _client.from('instructor_profiles').upsert(
        {'profile_id': userId},
        onConflict: 'profile_id',
      );
    } else {
      await _client.from('learner_profiles').upsert(
        {
          'profile_id': userId,
          'account_type': _normalizeLearnerAccountType(learnerAccountType),
        },
        onConflict: 'profile_id',
      );
    }

    // Keep auth metadata in sync because multiple screens read role from metadata.
    final currentUser = _client.auth.currentUser;
    if (currentUser?.id == userId) {
      try {
        await _client.auth.updateUser(
          UserAttributes(data: {
            'role': normalizedRole,
            if (normalizedRole == 'learner')
              'learnerAccountType':
                  _normalizeLearnerAccountType(learnerAccountType),
          }),
        );
      } catch (e) {
        print('Warning: unable to update auth role metadata: $e');
      }
    }
  }

  static Future<String?> resolveUserRole({
    required String userId,
    dynamic metadataRole,
  }) async {
    final normalizedMetadata = _normalizeRole(metadataRole);
    if (normalizedMetadata != null) return normalizedMetadata;

    try {
      final profile = await _client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      final profileRole = _normalizeRole(profile?['role']);
      if (profileRole != null) {
        final currentUser = _client.auth.currentUser;
        if (normalizedMetadata == null && currentUser?.id == userId) {
          try {
            await _client.auth.updateUser(
              UserAttributes(data: {'role': profileRole}),
            );
          } catch (e) {
            print('Warning: unable to sync role metadata from profile: $e');
          }
        }
        return profileRole;
      }
    } catch (e) {
      print('Warning: unable to resolve user role from profile: $e');
    }
    return null;
  }

  static Future<String?> getCurrentUserRole() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return resolveUserRole(
      userId: user.id,
      metadataRole: user.userMetadata?['role'],
    );
  }

  static User? get currentUser => _client.auth.currentUser;

  static Future<void> ensureCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
      }, onConflict: 'id');
    } catch (e) {
      print('Warning: unable to ensure current profile: $e');
    }
  }

  static String _generateTemporaryPassword() {
    return '${_generateFlowToken()}Aa1!';
  }

  static String _generateFlowToken() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static Future<void> updateOnboardingStage({
    required String userId,
    required String stage,
  }) async {
    await _client.from('profiles').update({
      'onboarding_stage': stage,
    }).eq('id', userId);
  }

  static Future<IdentityVerificationState?>
      getCurrentIdentityVerificationState() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return getIdentityVerificationState(user.id);
  }

  static Future<IdentityVerificationState?> getIdentityVerificationState(
    String userId,
  ) async {
    try {
      final response = await _client
          .from('profiles')
          .select(
            'id, role, first_name, age, created_at, is_verified, verification_status, verification_submitted_at, verification_review_started_at, verification_approved_at, identity_license_path, identity_selfie_path, guardian_identity_license_path, guardian_identity_selfie_path, guardian_consent_submitted_at, onboarding_stage',
          )
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;
      return IdentityVerificationState.fromJson(response);
    } catch (e) {
      print('Warning: unable to fetch identity verification state: $e');
      return null;
    }
  }

  static Future<String> resolvePostAuthRoute({
    required String userId,
    dynamic metadataRole,
  }) async {
    final role = await resolveUserRole(
      userId: userId,
      metadataRole: metadataRole,
    );
    final verificationState = await getIdentityVerificationState(userId);

    if (role == null) {
      return AppRoutes.roleSelection;
    }

    if (role == 'learner') {
      if (verificationState?.onboardingStage !=
          onboardingStageQuestionnaireComplete) {
        final learnerDetail = await getLearnerProfileDetail(userId);
        final accountType = _normalizeLearnerAccountType(
          learnerDetail?['account_type'],
        );
        if (accountType == 'guardian') {
          return '${AppRoutes.learnerQuestionnaire}?accountType=guardian';
        }
        return AppRoutes.learnerQuestionnaire;
      }

      try {
        final learnerDetail = await getLearnerProfileDetail(userId);
        final focus = (learnerDetail?['learning_focus'] as String?)?.trim();
        if (focus == null || focus.isEmpty) {
          return AppRoutes.learningFocus;
        }
      } catch (_) {
        return AppRoutes.learningFocus;
      }

      final identityStatus =
          verificationState?.verificationStatus?.trim().toLowerCase();
      if (verificationState?.hasRequiredIdentityDocuments != true ||
          identityStatus == 'rejected') {
        return AppRoutes.identityVerificationIntro;
      }
      if (identityStatus == 'pending') {
        return AppRoutes.identityPendingReview;
      }
      if (!(verificationState?.isApproved ?? false)) {
        return AppRoutes.identityPendingReview;
      }

      final approvalToken = verificationState?.verificationApprovedAt
              ?.toUtc()
              .toIso8601String() ??
          verificationState?.verificationStatus ??
          'approved';
      final shouldShowSuccess =
          await LaunchPreferences.shouldShowLearnerApprovalSuccess(
        userId: userId,
        approvalToken: approvalToken,
      );
      if (shouldShowSuccess) {
        return AppRoutes.learnerApprovalSuccess;
      }
      return AppRoutes.home;
    }

    if (role == 'instructor') {
      final identityStatus =
          verificationState?.verificationStatus?.trim().toLowerCase();
      final hasIdentityDocs =
          verificationState?.identityLicensePath?.trim().isNotEmpty == true &&
              verificationState?.identitySelfiePath?.trim().isNotEmpty == true;
      if (!hasIdentityDocs || identityStatus == 'rejected') {
        return AppRoutes.identityVerificationIntro;
      }

      if (verificationState?.onboardingStage !=
          onboardingStageQuestionnaireComplete) {
        return AppRoutes.instructorQuestionnaire;
      }

      final instructorDetail = await getInstructorProfileDetail(userId);
      final credentialsStatus =
          (instructorDetail?['credentials_status'] as String?)
              ?.trim()
              .toLowerCase();
      if (credentialsStatus == 'pending') {
        return AppRoutes.identityPendingReview;
      }
      if (credentialsStatus != 'approved') {
        return AppRoutes.instructorCredentialsPortal;
      }
      if (!(verificationState?.isApproved ?? false)) {
        return AppRoutes.identityPendingReview;
      }
      return AppRoutes.instructorHome;
    }
    return AppRoutes.roleSelection;
  }

  static Future<void> submitIdentityVerification({
    required String userId,
    required String role,
    required String licenseImagePath,
    required String selfieImagePath,
    String? guardianLicenseImagePath,
    String? guardianSelfieImagePath,
  }) async {
    final submittedAt = DateTime.now().toUtc().toIso8601String();
    final licensePath = await _uploadIdentityAsset(
      userId: userId,
      file: File(licenseImagePath),
      filePrefix: 'license',
    );
    final selfiePath = await _uploadIdentityAsset(
      userId: userId,
      file: File(selfieImagePath),
      filePrefix: 'selfie',
    );

    String? guardianLicensePath;
    String? guardianSelfiePath;
    if (guardianLicenseImagePath != null && guardianSelfieImagePath != null) {
      guardianLicensePath = await _uploadIdentityAsset(
        userId: userId,
        file: File(guardianLicenseImagePath),
        filePrefix: 'guardian-license',
      );
      guardianSelfiePath = await _uploadIdentityAsset(
        userId: userId,
        file: File(guardianSelfieImagePath),
        filePrefix: 'guardian-selfie',
      );
    }

    final updates = <String, dynamic>{
      'role': role,
      'verification_status': 'pending',
      'verification_submitted_at': submittedAt,
      'verification_review_started_at': null,
      'verification_approved_at': null,
      'identity_license_path': licensePath,
      'identity_selfie_path': selfiePath,
      'is_verified': false,
      'onboarding_stage': role == 'learner'
          ? onboardingStageQuestionnaireComplete
          : onboardingStageVerificationPending,
    };

    if (guardianLicensePath != null && guardianSelfiePath != null) {
      updates['guardian_identity_license_path'] = guardianLicensePath;
      updates['guardian_identity_selfie_path'] = guardianSelfiePath;
      updates['guardian_consent_submitted_at'] = submittedAt;
    }

    await _client.from('profiles').update(updates).eq('id', userId);
  }

  static Future<void> approveIdentityVerificationForTesting({
    required String userId,
    required String role,
  }) async {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    await _client.from('profiles').update({
      'role': role,
      'verification_status': 'approved',
      'verification_submitted_at': timestamp,
      'verification_review_started_at': timestamp,
      'verification_approved_at': timestamp,
      'identity_license_path': 'testing://license-skip',
      'identity_selfie_path': 'testing://selfie-skip',
      'guardian_identity_license_path': 'testing://guardian-license-skip',
      'guardian_identity_selfie_path': 'testing://guardian-selfie-skip',
      'guardian_consent_submitted_at': timestamp,
      'is_verified': role == 'learner',
    }).eq('id', userId);
  }

  static Future<void> uploadInstructorCredentialDocument({
    required String userId,
    required InstructorDocumentType documentType,
    required File file,
  }) async {
    final bytes = await file.readAsBytes();
    final extension = file.path.split('.').last.toLowerCase();
    final storagePath =
        '$userId/${documentType.storageKey}-${DateTime.now().millisecondsSinceEpoch}.$extension';

    await _client.storage.from(_instructorCredentialsBucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    await _client.from('instructor_profiles').upsert({
      'profile_id': userId,
      documentType.columnName: storagePath,
      'credentials_status': 'not_started',
    }, onConflict: 'profile_id');
  }

  static Future<void> submitInstructorCredentialsForReview({
    required String userId,
  }) async {
    final timestamp = DateTime.now().toUtc().toIso8601String();
    await _client.from('instructor_profiles').upsert({
      'profile_id': userId,
      'credentials_status': 'pending',
      'credentials_submitted_at': timestamp,
      'credentials_review_started_at': null,
      'credentials_approved_at': null,
    }, onConflict: 'profile_id');
    await updateProfileFields(userId, {'is_verified': false});
  }

  static Future<String> _uploadIdentityAsset({
    required String userId,
    required File file,
    required String filePrefix,
  }) async {
    final bytes = await file.readAsBytes();
    final fileExtension = file.path.split('.').last.toLowerCase();
    final storagePath =
        '$userId/$filePrefix-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    await _client.storage.from(_identityVerificationBucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return storagePath;
  }

  static Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // User Methods
  static Future<UserModel?> getUserProfile(String userId) async {
    try {
      final response =
          await _client.from('profiles').select().eq('id', userId).single();

      return UserModel.fromJson(response);
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  static Future<UserModel?> updateUserProfile(UserModel user) async {
    try {
      final response = await _client
          .from('profiles')
          .update(user.toJson())
          .eq('id', user.id)
          .select()
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      print('Error updating user profile: $e');
      return null;
    }
  }

  static Future<void> updateProfileFields(
      String userId, Map<String, dynamic> data) async {
    await _client.from('profiles').update(data).eq('id', userId);
  }

  static Future<String?> uploadProfileImage({
    required String userId,
    required File file,
  }) async {
    final bytes = await file.readAsBytes();
    final fileExtension = file.path.split('.').last;
    final filePath =
        'profile_images/$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    await _client.storage.from('avatars').uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final publicUrl = _client.storage.from('avatars').getPublicUrl(filePath);

    if (publicUrl.isNotEmpty) {
      await updateProfileFields(userId, {
        'profile_image_url': publicUrl,
      });
    }

    return publicUrl;
  }

  static Future<String?> uploadVehicleGalleryImage({
    required String userId,
    required File file,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final fileExtension = file.path.split('.').last;
      final filePath =
          'vehicle_gallery/$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      await _client.storage.from('instructor-assets').uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl =
          _client.storage.from('instructor-assets').getPublicUrl(filePath);
      if (publicUrl.isNotEmpty) {
        await _client
            .from('instructor_profiles')
            .update({'vehicle_photo_url': publicUrl}).eq('profile_id', userId);
      }

      return publicUrl;
    } catch (e) {
      print('Error uploading vehicle image: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getRawProfile(String userId) async {
    try {
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (profile == null) return null;
      return Map<String, dynamic>.from(profile);
    } catch (e) {
      print('Error fetching raw profile: $e');
      return null;
    }
  }

  static Future<void> requestAccountDeletion({
    String? reason,
    String? details,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception(
          'Please sign in again before requesting account deletion.');
    }

    String? role;
    try {
      role = await getCurrentUserRole();
    } catch (_) {}

    await _client.from('account_deletion_requests').insert({
      'profile_id': user.id,
      'role': role,
      'reason': reason?.trim().isEmpty == true ? null : reason?.trim(),
      'details': details?.trim().isEmpty == true ? null : details?.trim(),
      'status': 'requested',
      'metadata': {
        'source': 'mobile_app',
        'email': user.email,
      },
    });
  }

  static Future<Map<String, dynamic>?> getInstructorProfileDetail(
      String userId) async {
    try {
      final profile = await _client
          .from('instructor_profiles')
          .select('*, profile:profiles!instructor_profiles_profile_id_fkey(*)')
          .eq('profile_id', userId)
          .maybeSingle();
      if (profile == null) return null;
      return Map<String, dynamic>.from(profile);
    } catch (e) {
      print('Error fetching instructor profile: $e');
      return null;
    }
  }

  static Future<List<InstructorBillingPlan>> getInstructorBillingPlans() async {
    final rows = await _client
        .from('instructor_billing_plans')
        .select(
          'plan_key, display_name, description, amount_cents, currency, billing_interval, access_days, feature_codes',
        )
        .eq('is_active', true)
        .order('amount_cents');

    return (rows as List)
        .whereType<Map>()
        .map((row) => InstructorBillingPlan.fromJson(
              Map<String, dynamic>.from(row),
            ))
        .toList(growable: false);
  }

  static Future<InstructorBillingEntitlement?>
      getCurrentInstructorBillingEntitlement() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client
        .from('instructor_billing_entitlements')
        .select(
          'plan_key, status, access_expires_at, cancel_at_period_end',
        )
        .eq('profile_id', userId)
        .maybeSingle();

    if (row == null) return null;
    return InstructorBillingEntitlement.fromJson(
        Map<String, dynamic>.from(row));
  }

  static Future<bool> hasActiveInstructorBilling(String userId) async {
    final result = await _client.rpc<bool>(
      'instructor_has_active_billing',
      params: {'target_profile_id': userId},
    );
    return result == true;
  }

  static Future<Map<String, dynamic>?> getLearnerProfileDetail(
      String userId) async {
    try {
      final profile = await _client
          .from('learner_profiles')
          .select('*, profile:profiles!learner_profiles_profile_id_fkey(*)')
          .eq('profile_id', userId)
          .maybeSingle();
      if (profile == null) return null;

      try {
        final address = await _client
            .from('addresses')
            .select()
            .eq('profile_id', userId)
            .maybeSingle();
        if (address != null) {
          profile['home_address'] = address;
        }
      } catch (_) {}

      return profile;
    } catch (e) {
      print('Error fetching learner profile: $e');
      return null;
    }
  }

  static Future<void> upsertInstructorProfile({
    required String userId,
    String? bio,
    double? defaultRate,
    List<Map<String, dynamic>>? vehicles,
    List<String>? offerings,
    Map<String, double>? offeringRates,
    List<Map<String, dynamic>>? preferredLocations,
    bool clearPreferredLocations = false,
    String? preferredLocationNotes,
    int? yearsOfExperience,
    String? vehiclePhotoUrl,
    bool? pickupPreference,
  }) async {
    String? cleanString(String? value) {
      if (value == null) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final data = <String, dynamic>{
      'profile_id': userId,
    };

    final cleanedBio = cleanString(bio);
    if (cleanedBio != null) {
      data['bio'] = cleanedBio;
    }
    if (defaultRate != null) {
      data['default_rate'] = defaultRate;
    } else if (offeringRates != null && offeringRates.isNotEmpty) {
      data['default_rate'] = offeringRates.values.first;
    }
    if (vehicles != null) {
      data['vehicles'] = vehicles;
    }
    if (offerings != null) {
      data['offerings'] = offerings;
    }
    if (offeringRates != null) {
      data['offering_rates'] =
          offeringRates.map((key, value) => MapEntry(key, value.toDouble()));
    }
    if (preferredLocations != null || clearPreferredLocations) {
      data['preferred_locations'] = preferredLocations;
    }
    final cleanedLocationNotes = cleanString(preferredLocationNotes);
    if (cleanedLocationNotes != null) {
      data['preferred_location_notes'] = cleanedLocationNotes;
    }
    if (yearsOfExperience != null) {
      data['years_of_experience'] = yearsOfExperience;
    }
    final cleanedVehiclePhotoUrl = cleanString(vehiclePhotoUrl);
    if (cleanedVehiclePhotoUrl != null) {
      data['vehicle_photo_url'] = cleanedVehiclePhotoUrl;
    }
    if (pickupPreference != null) {
      data['pickup_preference'] = pickupPreference;
    }

    await _client
        .from('instructor_profiles')
        .upsert(data, onConflict: 'profile_id');
  }

  static Future<void> upsertLearnerProfile({
    required String userId,
    String? learningFocus,
    DateTime? targetTestDate,
    String? targetTestCentre,
    String? notes,
    String? accountType,
    String? wardFirstName,
    String? wardLastName,
    int? wardAge,
    String? wardGender,
    int? classesTakenSoFar,
    DateTime? lastClassDate,
    List<Map<String, dynamic>>? preferredLocations,
    String? preferredLocationNotes,
    List<Map<String, dynamic>>? weeklyAvailability,
    bool? availabilityRecurring,
  }) async {
    String? cleanString(String? value) {
      if (value == null) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final data = <String, dynamic>{'profile_id': userId};

    final cleanedFocus = cleanString(learningFocus);
    if (cleanedFocus != null) {
      data['learning_focus'] = cleanedFocus;
    }
    if (targetTestDate != null) {
      data['target_test_date'] = targetTestDate.toIso8601String();
    }
    final cleanedCentre = cleanString(targetTestCentre);
    if (cleanedCentre != null) {
      data['target_test_centre'] = cleanedCentre;
    }
    final cleanedNotes = cleanString(notes);
    if (cleanedNotes != null) {
      data['notes'] = cleanedNotes;
    }
    if (classesTakenSoFar != null) {
      data['classes_taken_sofar'] = classesTakenSoFar;
    }
    final cleanedAccountType = cleanString(accountType);
    if (cleanedAccountType != null) {
      data['account_type'] = _normalizeLearnerAccountType(cleanedAccountType);
    }
    final cleanedWardFirst = cleanString(wardFirstName);
    if (cleanedWardFirst != null) {
      data['ward_first_name'] = cleanedWardFirst;
    }
    final cleanedWardLast = cleanString(wardLastName);
    if (cleanedWardLast != null) {
      data['ward_last_name'] = cleanedWardLast;
    }
    if (wardAge != null) {
      data['ward_age'] = wardAge;
    }
    final cleanedWardGender = cleanString(wardGender);
    if (cleanedWardGender != null) {
      data['ward_gender'] = cleanedWardGender;
    }
    if (lastClassDate != null) {
      data['last_class_date'] = lastClassDate.toIso8601String();
    }
    if (preferredLocations != null) {
      data['preferred_locations'] = preferredLocations;
    }
    final cleanedLocationNotes = cleanString(preferredLocationNotes);
    if (cleanedLocationNotes != null) {
      data['preferred_location_notes'] = cleanedLocationNotes;
    }
    if (weeklyAvailability != null) {
      data['weekly_availability'] =
          _normalizeWeeklyAvailabilityPayload(weeklyAvailability);
    }
    if (availabilityRecurring != null) {
      data['availability_recurring'] = availabilityRecurring;
    }

    await _client
        .from('learner_profiles')
        .upsert(data, onConflict: 'profile_id');
  }

  static Future<void> submitLearnerOnboardingDraft({
    required LearnerOnboardingDraft draft,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Please sign in again to continue.');
    }

    final profileUpdates = <String, dynamic>{};
    final firstName = draft.firstName?.trim();
    if (firstName != null && firstName.isNotEmpty) {
      profileUpdates['first_name'] = firstName;
    }
    final lastName = draft.lastName?.trim();
    if (lastName != null && lastName.isNotEmpty) {
      profileUpdates['last_name'] = lastName;
    }
    final phone = draft.phone?.trim();
    if (phone != null && phone.isNotEmpty) {
      profileUpdates['phone'] = phone;
    }
    final licenceNumber = draft.g1LicenceNumber?.trim().toUpperCase();
    if (licenceNumber != null && licenceNumber.isNotEmpty) {
      profileUpdates['licence_number'] = licenceNumber;
    }
    if (draft.g1ExpiryDate != null) {
      final expiry = draft.g1ExpiryDate!;
      final endOfDay = DateTime(
        expiry.year,
        expiry.month,
        expiry.day,
        23,
        59,
        59,
      );
      profileUpdates['licence_expiry'] = endOfDay.toIso8601String();
    }
    final city = draft.city?.trim();
    if (city != null && city.isNotEmpty) {
      profileUpdates['city'] = city;
    }
    if (draft.age != null && draft.learnerAccountType != 'guardian') {
      profileUpdates['age'] = draft.age;
    }
    final gender = draft.gender?.trim();
    if (gender != null &&
        gender.isNotEmpty &&
        draft.learnerAccountType != 'guardian') {
      profileUpdates['gender'] = gender;
    }

    if (profileUpdates.isNotEmpty) {
      await updateProfileFields(userId, profileUpdates);
    }

    await upsertLearnerProfile(
      userId: userId,
      accountType: draft.learnerAccountType,
      wardFirstName: draft.wardFirstName,
      wardLastName: draft.wardLastName,
      wardAge: draft.learnerAccountType == 'guardian' ? draft.age : null,
      wardGender: draft.learnerAccountType == 'guardian' ? draft.gender : null,
      classesTakenSoFar: draft.classesTakenSoFar,
      lastClassDate: draft.lastClassDate,
      preferredLocations: draft.preferredLocationsPayload,
      weeklyAvailability: draft.weeklyAvailabilityPayload,
      availabilityRecurring: draft.availabilityRecurring,
    );
  }

  static Future<List<Map<String, dynamic>>> getLearnerSkillProgress(
      String userId) async {
    try {
      final response = await _client
          .from('learner_skill_progress')
          .select()
          .eq('profile_id', userId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching learner skill progress: $e');
      return [];
    }
  }

  static Future<Map<String, int>> getLearnerProgressCounts(
      List<String> learnerIds) async {
    if (learnerIds.isEmpty) return {};
    final response = await _client
        .from('learner_skill_progress')
        .select('profile_id, is_completed, status')
        .inFilter('profile_id', learnerIds);
    final counts = <String, int>{};
    for (final row in response) {
      final profileId = row['profile_id']?.toString();
      if (profileId == null || profileId.isEmpty) continue;
      final status = row['status']?.toString().trim().toLowerCase();
      final isCompleted = row['is_completed'] == true ||
          status == 'test_ready' ||
          status == 'completed';
      if (isCompleted) {
        counts.update(profileId, (value) => value + 1, ifAbsent: () => 1);
      } else {
        counts.putIfAbsent(profileId, () => 0);
      }
    }
    return counts;
  }

  static Future<Map<String, DateTime>> getNextLessonsForLearners({
    required String instructorId,
    required List<String> learnerIds,
  }) async {
    if (learnerIds.isEmpty) return {};
    final nowUtc = DateTime.now().toUtc();
    final rows = await _client
        .from('lessons')
        .select('learner_id, scheduled_at, start_time')
        .eq('instructor_id', instructorId)
        .inFilter('learner_id', learnerIds)
        .inFilter('status', ['scheduled', 'active', 'in_progress'])
        .gte('scheduled_at', nowUtc.toIso8601String())
        .order('scheduled_at', ascending: true);

    final nextMap = <String, DateTime>{};

    DateTime? _combine(DateTime date, dynamic rawTime) {
      if (rawTime == null) return null;
      final timeString = rawTime.toString();
      final parts = timeString.split(':');
      if (parts.length < 2) return null;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return null;
      return DateTime(date.year, date.month, date.day, hour, minute);
    }

    for (final row in rows) {
      final learnerId = row['learner_id']?.toString();
      if (learnerId == null || learnerId.isEmpty) continue;
      if (nextMap.containsKey(learnerId)) continue;
      final scheduledRaw = row['scheduled_at']?.toString();
      if (scheduledRaw == null) continue;
      final scheduled = DateTime.tryParse(scheduledRaw);
      if (scheduled == null) continue;
      final localDate = scheduled.toLocal();
      final start = _combine(localDate, row['start_time']) ?? localDate;
      nextMap[learnerId] = start;
    }

    return nextMap;
  }

  static Map<String, dynamic> _normalizeWeeklyAvailabilityPayload(
      dynamic value) {
    final normalized = <String, dynamic>{};

    void addSlots(String dayKey, Iterable<dynamic> slots) {
      final key = dayKey.trim().toLowerCase();
      if (key.isEmpty) return;
      final slotList = slots
          .whereType<String>()
          .map((slot) => slot.trim())
          .where((slot) => slot.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      if (slotList.isNotEmpty) {
        normalized[key] = slotList;
      }
    }

    if (value is Map) {
      value.forEach((day, slots) {
        if (day == null) return;
        if (slots is List) {
          addSlots(day.toString(), slots);
        } else if (slots is Map && slots['slots'] is List) {
          addSlots(day.toString(), slots['slots'] as List);
        }
      });
    } else if (value is Iterable) {
      for (final entry in value) {
        if (entry is Map) {
          final day = entry['day']?.toString();
          final slots = entry['slots'];
          if (day != null && slots is Iterable) {
            addSlots(day, slots);
          }
        }
      }
    }

    return normalized;
  }

  static Future<void> upsertLearnerSkillProgress({
    required String userId,
    required String skillId,
    required String status,
    String updatedByRole = 'learner',
  }) async {
    final normalizedStatus = status.trim().toLowerCase();
    final isCompleted =
        normalizedStatus == 'test_ready' || normalizedStatus == 'completed';
    final now = DateTime.now().toUtc();
    await _client.from('learner_skill_progress').upsert({
      'profile_id': userId,
      'skill_id': skillId,
      'status': normalizedStatus,
      'is_completed': isCompleted,
      'completed_at': isCompleted ? now.toIso8601String() : null,
      'updated_by': currentUser?.id,
      'updated_by_role': updatedByRole,
      'updated_at': now.toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getInstructorAvailability(
      String userId) async {
    final results = await _client
        .from('instructor_availability')
        .select()
        .eq('instructor_id', userId)
        .order('weekday');
    return List<Map<String, dynamic>>.from(results);
  }

  static Future<void> addAvailabilitySlot({
    required String userId,
    required int weekday,
    required String startTime,
    required String endTime,
  }) async {
    await _client.from('instructor_availability').insert({
      'instructor_id': userId,
      'weekday': weekday,
      'start_time': startTime,
      'end_time': endTime,
    });
  }

  static Future<void> deleteAvailabilitySlot(String slotId) async {
    await _client.from('instructor_availability').delete().eq('id', slotId);
  }

  static Future<void> saveRecurringAvailability({
    required String userId,
    required List<Map<String, dynamic>> slots,
  }) async {
    await _client
        .from('instructor_availability')
        .delete()
        .eq('instructor_id', userId);
    if (slots.isEmpty) {
      return;
    }

    final payload = slots
        .map((slot) => {
              'instructor_id': userId,
              'weekday': slot['weekday'],
              'start_time': slot['start_time'],
              'end_time': slot['end_time'],
            })
        .toList();

    await _client.from('instructor_availability').insert(payload);
  }

  static Future<List<Map<String, dynamic>>> getAvailabilityBlocks(
      String userId) async {
    final results = await _client
        .from('instructor_availability_blocks')
        .select()
        .eq('instructor_id', userId)
        .order('block_date');
    return List<Map<String, dynamic>>.from(results);
  }

  static Future<void> addAvailabilityBlock({
    required String userId,
    required DateTime date,
    String? reason,
    String? startTime,
    String? endTime,
    bool isAllDay = false,
  }) async {
    final payload = <String, dynamic>{
      'instructor_id': userId,
      'block_date': date.toIso8601String(),
      'reason': reason,
      'is_all_day': isAllDay,
      'start_time': startTime,
      'end_time': endTime,
    }..removeWhere((_, value) => value == null);

    await _client.from('instructor_availability_blocks').insert(payload);
  }

  static Future<void> removeAvailabilityBlock(String blockId) async {
    await _client
        .from('instructor_availability_blocks')
        .delete()
        .eq('id', blockId);
  }

  static Future<List<Map<String, dynamic>>> getLessonRequestsForInstructor(
      String userId) async {
    final results = await _client
        .from('learner_requests')
        .select(
            '*, learner_profile:learner_profiles!learner_requests_learner_id_fkey(account_type, ward_first_name, ward_last_name, ward_age, ward_gender, weekly_availability, availability_recurring, profile:profiles!learner_profiles_profile_id_fkey(id, first_name, last_name,phone, profile_image_url, city, gender, age))')
        .eq('instructor_id', userId)
        .order('created_at', ascending: false);
    final requests = List<Map<String, dynamic>>.from(results);
    return _hydrateLessonRequests(requests);
  }

  static Future<List<Map<String, dynamic>>> getLessonRequestsForLearner(
      String userId) async {
    final results = await _client
        .from('learner_requests')
        .select(
            '*, instructor_profile:instructor_profiles!lesson_requests_instructor_id_fkey(*, user:profiles!instructor_profiles_profile_id_fkey(*))')
        .eq('learner_id', userId)
        .order('created_at', ascending: false);
    final requests = List<Map<String, dynamic>>.from(results);
    return _hydrateLessonRequests(requests);
  }

  static void _normalizeLearnerSnapshot(Map<String, dynamic> request) {
    final learnerProfile = request['learner_profile'];
    if (learnerProfile is Map<String, dynamic>) {
      final profile = learnerProfile['profile'];
      if (profile is Map<String, dynamic>) {
        final profileMap = Map<String, dynamic>.from(profile);
        request['learner'] = profileMap;
        request['learner_email'] ??= profileMap['email'];
        request['requested_first_name'] ??= profileMap['first_name'];
        request['requested_last_name'] ??= profileMap['last_name'];
        request['requested_profile_url'] ??= profileMap['profile_image_url'];
        request['requested_avatar_url'] ??= profileMap['profile_image_url'];
        request['requested_phone'] ??= profileMap['phone'];
        final nameParts = <String>[];
        final first = profileMap['first_name'];
        final last = profileMap['last_name'];
        if (first is String && first.trim().isNotEmpty) {
          nameParts.add(first.trim());
        }
        if (last is String && last.trim().isNotEmpty) {
          nameParts.add(last.trim());
        }
        if (nameParts.isNotEmpty) {
          request['requested_name'] ??= nameParts.join(' ');
        }
      }
    }
    final learner = request['learner'];
    if (learner is Map<String, dynamic>) {
      request['learner'] = Map<String, dynamic>.from(learner);
    }
  }

  static Future<Map<String, Map<String, dynamic>>> _fetchLearnerProfiles(
      Set<String> learnerIds) async {
    final ids = learnerIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return const <String, Map<String, dynamic>>{};

    final rows = await _client
        .from('learner_profiles')
        .select(
            'profile_id, account_type, ward_first_name, ward_last_name, ward_age, ward_gender, learning_focus, target_test_date, target_test_centre, notes, classes_taken_sofar, last_class_date, preferred_locations, preferred_location_notes, weekly_availability, availability_recurring, profile:profiles!learner_profiles_profile_id_fkey(id, first_name, last_name, email, phone, profile_image_url, city, gender, age, licence_number, licence_expiry)')
        .inFilter('profile_id', ids.toList());

    final map = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final profileId = row['profile_id']?.toString();
      if (profileId != null && profileId.isNotEmpty) {
        map[profileId] = Map<String, dynamic>.from(row as Map);
      }
    }
    return map;
  }

  static void _applyLearnerProfileData(
    Map<String, dynamic> target,
    Map<String, dynamic>? learnerProfile,
  ) {
    if (learnerProfile == null) return;

    final normalizedProfile = Map<String, dynamic>.from(learnerProfile);
    final nestedProfile = normalizedProfile['profile'] is Map
        ? Map<String, dynamic>.from(normalizedProfile['profile'] as Map)
        : const <String, dynamic>{};

    final existingProfile = target['learner_profile'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(target['learner_profile'] as Map)
        : <String, dynamic>{};
    normalizedProfile.remove('profile');
    target['learner_profile'] = {
      ...existingProfile,
      ...normalizedProfile,
    };

    void setIfMissing(String key, dynamic value) {
      if (value == null) return;
      if (!target.containsKey(key) || target[key] == null) {
        target[key] = value;
      }
    }

    for (final key in [
      'learning_focus',
      'target_test_date',
      'target_test_centre',
      'notes',
      'account_type',
      'ward_first_name',
      'ward_last_name',
      'ward_age',
      'ward_gender',
      'classes_taken_sofar',
      'last_class_date',
      'preferred_locations',
      'preferred_location_notes',
    ]) {
      setIfMissing(key, normalizedProfile[key]);
    }

    Map<String, dynamic>? normalizedAvailability;
    if (normalizedProfile['weekly_availability'] != null) {
      normalizedAvailability = _normalizeWeeklyAvailabilityPayload(
        normalizedProfile['weekly_availability'],
      );
      target['weekly_availability'] ??= normalizedAvailability;
    }
    if (target['availability_recurring'] == null &&
        normalizedProfile.containsKey('availability_recurring')) {
      target['availability_recurring'] =
          normalizedProfile['availability_recurring'];
    }

    if (nestedProfile.isNotEmpty) {
      final learner = target['learner'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(target['learner'] as Map)
          : <String, dynamic>{};
      learner.addAll(nestedProfile);
      target['learner'] = learner;
      final learnerProfileMap =
          Map<String, dynamic>.from(target['learner_profile'] as Map);
      for (final key in [
        'first_name',
        'last_name',
        'email',
        'phone',
        'profile_image_url',
        'city',
        'gender',
        'age',
        'licence_number',
        'licence_expiry',
      ]) {
        learnerProfileMap.putIfAbsent(key, () => nestedProfile[key]);
      }
      if (normalizedAvailability != null) {
        learnerProfileMap['weekly_availability'] = normalizedAvailability;
      }
      learnerProfileMap.putIfAbsent('availability_recurring',
          () => normalizedProfile['availability_recurring']);
      target['learner_profile'] = learnerProfileMap;
      target['learner_email'] ??= nestedProfile['email'];
      target['requested_first_name'] ??= nestedProfile['first_name'];
      target['requested_last_name'] ??= nestedProfile['last_name'];
      target['requested_phone'] ??= nestedProfile['phone'];
      target['requested_profile_url'] ??= nestedProfile['profile_image_url'];
      target['requested_avatar_url'] ??= nestedProfile['profile_image_url'];
      final nameParts = <String>[];
      final first = (nestedProfile['first_name'] as String?)?.trim() ?? '';
      final last = (nestedProfile['last_name'] as String?)?.trim() ?? '';
      if (first.isNotEmpty) nameParts.add(first);
      if (last.isNotEmpty) nameParts.add(last);
      if (nameParts.isNotEmpty) {
        target['requested_name'] ??= nameParts.join(' ');
      }
    }
  }

  static Future<List<Map<String, dynamic>>> _hydrateLessonRequests(
      List<Map<String, dynamic>> requests) async {
    final missingLearnerIds = <String>{};
    final learnerIds = <String>{};

    String _clean(dynamic value) {
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return '';
        return trimmed;
      }
      return '';
    }

    bool _learnerHasDetails(Map<String, dynamic>? learner) {
      if (learner == null) return false;
      final first = learner['first_name'] as String?;
      final last = learner['last_name'] as String?;
      final email = learner['email'] as String?;
      final phone = learner['phone'];
      final hasIdentity = (first != null && first.trim().isNotEmpty) ||
          (last != null && last.trim().isNotEmpty) ||
          (email != null && email.trim().isNotEmpty);
      final hasPhone = phone != null && phone.toString().trim().isNotEmpty;
      return hasIdentity && hasPhone;
    }

    for (final request in requests) {
      _normalizeLearnerSnapshot(request);
      final learnerId = request['learner_id'] as String?;
      if (learnerId != null && learnerId.isNotEmpty) {
        learnerIds.add(learnerId);
      }
    }

    final learnerProfileMap = await _fetchLearnerProfiles(learnerIds);
    for (final request in requests) {
      final learnerId = request['learner_id'] as String?;
      if (learnerId != null && learnerId.isNotEmpty) {
        _applyLearnerProfileData(request, learnerProfileMap[learnerId]);
      }
    }

    for (final request in requests) {
      final learner = request['learner'];
      if (_learnerHasDetails(
          learner is Map<String, dynamic> ? learner : null)) {
        continue;
      }
      final learnerId = request['learner_id'] as String?;
      if (learnerId != null && learnerId.isNotEmpty) {
        missingLearnerIds.add(learnerId);
      }
    }

    if (missingLearnerIds.isEmpty) return requests;

    final ids = missingLearnerIds.toList();
    final profiles = await _client
        .from('profiles')
        .select(
            'id, first_name, last_name, email, phone, profile_image_url, city, gender, age')
        .inFilter('id', ids);

    final profileMap = <String, Map<String, dynamic>>{};
    for (final row in profiles) {
      final id = row['id'] as String?;
      if (id != null) {
        profileMap[id] = Map<String, dynamic>.from(row);
      }
    }

    for (final request in requests) {
      final learnerId = request['learner_id'] as String?;
      if (learnerId == null) continue;
      final profile = profileMap[learnerId];
      if (profile != null) {
        final normalizedProfile = Map<String, dynamic>.from(profile);
        request['learner'] = normalizedProfile;
        request['learner_email'] ??= normalizedProfile['email'];
        request['requested_first_name'] ??= normalizedProfile['first_name'];
        request['requested_last_name'] ??= normalizedProfile['last_name'];
        request['requested_phone'] ??= normalizedProfile['phone'];
        request['requested_profile_url'] ??=
            normalizedProfile['profile_image_url'];
        request['requested_avatar_url'] ??=
            normalizedProfile['profile_image_url'];
        final nameParts = <String>[];
        final normalizedFirst = _clean(normalizedProfile['first_name']);
        final normalizedLast = _clean(normalizedProfile['last_name']);
        if (normalizedFirst.isNotEmpty) {
          nameParts.add(normalizedFirst);
        }
        if (normalizedLast.isNotEmpty) {
          nameParts.add(normalizedLast);
        }
        if (nameParts.isNotEmpty) {
          request['requested_name'] ??= nameParts.join(' ');
        }
      }
      final learnerMap = request['learner'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(request['learner'] as Map)
          : <String, dynamic>{};
      learnerMap['first_name'] ??= request['requested_first_name'];
      learnerMap['last_name'] ??= request['requested_last_name'];
      learnerMap['phone'] ??= request['requested_phone'];
      learnerMap['profile_image_url'] ??=
          request['requested_profile_url'] ?? request['requested_avatar_url'];
      final requestedFullName = [
        request['requested_first_name'],
        request['requested_last_name'],
      ].map(_clean).where((value) => value.isNotEmpty).join(' ');
      final candidateNameOrder = [
        learnerMap['name'],
        requestedFullName,
        request['requested_name'],
        request['learner_email'],
        learnerMap['email'],
      ];
      for (final candidate in candidateNameOrder) {
        final value = _clean(candidate);
        if (value.isNotEmpty) {
          learnerMap['name'] = value;
          break;
        }
      }
      request['learner'] = learnerMap;
    }

    return requests;
  }

  static Future<List<Map<String, dynamic>>> _hydrateLessonLearners(
      List<Map<String, dynamic>> lessons) async {
    String? _fallbackName(Map<String, dynamic> map) {
      String _clean(dynamic value) {
        if (value == null) return '';
        final text = value.toString().trim();
        return text.isEmpty ? '' : text;
      }

      String combine(dynamic first, dynamic last) {
        final parts = [_clean(first), _clean(last)]
            .where((value) => value.isNotEmpty)
            .toList();
        return parts.join(' ').trim();
      }

      final learner = map['learner'];
      if (learner is Map) {
        final combined = combine(learner['first_name'], learner['last_name']);
        if (combined.isNotEmpty) return combined;
        final email = _clean(learner['email']);
        if (email.isNotEmpty) return email;
        final name = _clean(learner['name']);
        if (name.isNotEmpty) return name;
      } else if (learner is String && learner.trim().isNotEmpty) {
        return learner.trim();
      }

      final profile = map['learner_profile'];
      if (profile is Map) {
        final combined = combine(profile['first_name'], profile['last_name']);
        if (combined.isNotEmpty) return combined;
        final email = _clean(profile['email']);
        if (email.isNotEmpty) return email;
        final name = _clean(profile['name']);
        if (name.isNotEmpty) return name;
        if (profile['profile'] is Map) {
          final nested = Map<String, dynamic>.from(profile['profile'] as Map);
          final nestedCombined =
              combine(nested['first_name'], nested['last_name']);
          if (nestedCombined.isNotEmpty) return nestedCombined;
          final nestedEmail = _clean(nested['email']);
          if (nestedEmail.isNotEmpty) return nestedEmail;
          final nestedName = _clean(nested['name']);
          if (nestedName.isNotEmpty) return nestedName;
        }
      }

      final requested = combine(
          map['requested_first_name'] ?? map['requested_name'] ?? '',
          map['requested_last_name']);
      if (requested.isNotEmpty) return requested;

      final requestedEmail = _clean(map['learner_email']);
      if (requestedEmail.isNotEmpty) return requestedEmail;

      return null;
    }

    final learnerIds = <String>{};
    for (final lesson in lessons) {
      final learnerId = lesson['learner_id']?.toString();
      if (learnerId != null && learnerId.isNotEmpty) {
        learnerIds.add(learnerId);
      }
    }

    final learnerProfileMap = await _fetchLearnerProfiles(learnerIds);
    for (final lesson in lessons) {
      final learnerId = lesson['learner_id']?.toString();
      if (learnerId != null && learnerId.isNotEmpty) {
        _applyLearnerProfileData(lesson, learnerProfileMap[learnerId]);
      }
    }

    bool _hasIdentity(Map<String, dynamic>? learner) {
      if (learner == null) return false;
      final first = (learner['first_name'] as String?)?.trim() ?? '';
      final last = (learner['last_name'] as String?)?.trim() ?? '';
      final email = (learner['email'] as String?)?.trim() ?? '';
      return first.isNotEmpty || last.isNotEmpty || email.isNotEmpty;
    }

    final missingIds = <String>{};
    for (final lesson in lessons) {
      final learner = lesson['learner'];
      if (_hasIdentity(learner is Map<String, dynamic> ? learner : null)) {
        continue;
      }
      final learnerId = lesson['learner_id']?.toString();
      if (learnerId != null && learnerId.isNotEmpty) {
        missingIds.add(learnerId);
      }
    }

    Map<String, dynamic>? _profileFor(
        String? learnerId, Map<String, Map<String, dynamic>> profiles) {
      if (learnerId == null || learnerId.isEmpty) return null;
      final profile = profiles[learnerId];
      return profile != null ? Map<String, dynamic>.from(profile) : null;
    }

    Map<String, Map<String, dynamic>> profileById = const {};
    if (missingIds.isNotEmpty) {
      final profileRows = await _client
          .from('profiles')
          .select('id, first_name, last_name, email, profile_image_url, city')
          .inFilter('id', missingIds.toList());
      profileById = {};
      for (final row in profileRows) {
        final id = row['id'] as String?;
        if (id != null) {
          profileById[id] = Map<String, dynamic>.from(row);
        }
      }
    }

    for (final lesson in lessons) {
      final learnerId = lesson['learner_id']?.toString();
      if (learnerId == null || learnerId.isEmpty) continue;
      final existing = lesson['learner'];
      Map<String, dynamic>? learnerMap;
      if (existing is Map<String, dynamic>) {
        learnerMap = Map<String, dynamic>.from(existing);
      }
      final fallbackProfile = _profileFor(learnerId, profileById);
      if (fallbackProfile != null) {
        if (learnerMap == null) {
          learnerMap = fallbackProfile;
        } else {
          learnerMap.addAll(fallbackProfile);
        }
      }
      if (learnerMap != null) {
        lesson['learner'] = learnerMap;
        final displayName = _formatProfileName(learnerMap);
        if (displayName != null && displayName.isNotEmpty) {
          lesson['learner_name'] = displayName;
          learnerMap.putIfAbsent('name', () => displayName);
        } else {
          final fallback = _fallbackName(lesson);
          if (fallback != null && fallback.isNotEmpty) {
            lesson['learner_name'] = fallback;
            learnerMap.putIfAbsent('name', () => fallback);
          }
        }
      } else {
        final fallback = _fallbackName(lesson);
        if (fallback != null && fallback.isNotEmpty) {
          lesson['learner_name'] = fallback;
        }
      }
    }

    return lessons;
  }

  static String? _formatProfileName(Map<String, dynamic> profile) {
    final first = (profile['first_name'] as String?)?.trim();
    final last = (profile['last_name'] as String?)?.trim();
    final parts = <String>[];
    if (first != null && first.isNotEmpty) parts.add(first);
    if (last != null && last.isNotEmpty) parts.add(last);
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    final email = (profile['email'] as String?)?.trim();
    if (email != null && email.isNotEmpty) return email;
    return null;
  }

  static Future<Map<String, dynamic>?> respondToLessonRequest({
    required String requestId,
    required String status,
  }) async {
    final result = await _client
        .from('learner_requests')
        .update({'status': status})
        .eq('id', requestId)
        .select(
            '*, learner_profile:learner_profiles!learner_requests_learner_id_fkey(account_type, ward_first_name, ward_last_name, ward_age, ward_gender, weekly_availability, availability_recurring, profile:profiles!learner_profiles_profile_id_fkey(id, first_name, last_name, email, profile_image_url, city, gender, age))')
        .maybeSingle();
    if (result == null) return null;
    final hydrated = await _hydrateLessonRequests(
        [Map<String, dynamic>.from(result as Map)]);
    return hydrated.isNotEmpty ? hydrated.first : null;
  }

  static Future<void> createLessonRequest({
    required String instructorId,
    required String learnerId,
    String? focus,
    String? message,
    String? requestedVehicleLabel,
    String? requestedVehicleType,
  }) async {
    final existing = await _client
        .from('learner_requests')
        .select('id, status, updated_at')
        .eq('instructor_id', instructorId)
        .eq('learner_id', learnerId)
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      final status = (existing['status'] as String?)?.toLowerCase();
      if (status == 'pending' || status == 'accepted') {
        throw Exception(
            'You already have a pending request with this instructor.');
      }
      if (status == 'declined') {
        final updatedAtRaw = existing['updated_at']?.toString();
        final updatedAt = DateTime.tryParse(updatedAtRaw ?? '');
        if (updatedAt != null) {
          final cooldownEnd = updatedAt.add(const Duration(days: 7));
          final now = DateTime.now();
          if (now.isBefore(cooldownEnd)) {
            final remaining = cooldownEnd.difference(now);
            final days = remaining.inDays;
            final hours = remaining.inHours.remainder(24);
            String remainingText;
            if (days >= 1) {
              remainingText = '$days day${days == 1 ? '' : 's'}';
            } else if (hours > 0) {
              remainingText = '$hours hour${hours == 1 ? '' : 's'}';
            } else {
              remainingText = 'less than an hour';
            }
            throw Exception(
                'You can request this instructor again in $remainingText.');
          }
        }
      }
    }

    Map<String, dynamic>? learnerSnapshot;
    try {
      learnerSnapshot = await getRawProfile(learnerId);
    } catch (_) {}

    String? _clean(dynamic value) {
      if (value is String) {
        final trimmed = value.trim();
        return trimmed.isEmpty || trimmed.toLowerCase() == 'null'
            ? null
            : trimmed;
      }
      return null;
    }

    final requestedFirst = _clean(learnerSnapshot?['first_name']);
    final requestedLast = _clean(learnerSnapshot?['last_name']);
    final requestedProfileUrl = _clean(learnerSnapshot?['profile_image_url']);
    final requestedPhone = _clean(learnerSnapshot?['phone']);
    final requestedGender = _clean(learnerSnapshot?['gender']);
    final requestedCity = _clean(learnerSnapshot?['city']);
    final requestedAge = learnerSnapshot?['age'];
    final normalizedFocus = _clean(focus)?.trim();
    final normalizedMessage = _clean(message)?.trim();
    final normalizedVehicleLabel = _clean(requestedVehicleLabel)?.trim();
    final normalizedVehicleType = _clean(requestedVehicleType)?.trim();

    await _client.from('learner_requests').insert({
      'instructor_id': instructorId,
      'learner_id': learnerId,
      'focus': normalizedFocus?.isNotEmpty == true ? normalizedFocus : null,
      'message':
          normalizedMessage?.isNotEmpty == true ? normalizedMessage : null,
      'requested_vehicle_label': normalizedVehicleLabel?.isNotEmpty == true
          ? normalizedVehicleLabel
          : null,
      'requested_vehicle_type': normalizedVehicleType?.isNotEmpty == true
          ? normalizedVehicleType
          : null,
      'status': 'pending',
      'requested_first_name': requestedFirst,
      'requested_last_name': requestedLast,
      'requested_profile_url': requestedProfileUrl,
      'requested_phone': requestedPhone,
      'requested_gender': requestedGender,
      'requested_city': requestedCity,
      'requested_age': requestedAge,
    });
  }

  static Future<Map<String, dynamic>?> getLearnerRequestById(
      String requestId) async {
    final result = await _client
        .from('learner_requests')
        .select(
            '*, learner_profile:learner_profiles!learner_requests_learner_id_fkey(account_type, ward_first_name, ward_last_name, ward_age, ward_gender, weekly_availability, availability_recurring, profile:profiles!learner_profiles_profile_id_fkey(id, first_name, last_name, email, phone, profile_image_url, city, gender, age))')
        .eq('id', requestId)
        .maybeSingle();
    if (result == null) return null;
    final hydrated = await _hydrateLessonRequests(
        [Map<String, dynamic>.from(result as Map)]);
    return hydrated.isNotEmpty ? hydrated.first : null;
  }

  static Future<Map<String, dynamic>?> getActiveLessonRequest({
    required String instructorId,
    required String learnerId,
  }) async {
    final request = await _client
        .from('learner_requests')
        .select(
            'id, status, focus, message, created_at, requested_vehicle_label, requested_vehicle_type')
        .eq('instructor_id', instructorId)
        .eq('learner_id', learnerId)
        .or('status.eq.pending,status.eq.accepted')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (request == null) return null;
    return Map<String, dynamic>.from(request);
  }

  static Future<List<Map<String, dynamic>>> getActiveLessonRequestsForLearner(
      String learnerId) async {
    final results = await _client
        .from('learner_requests')
        .select('id, instructor_id, status, updated_at, created_at')
        .eq('learner_id', learnerId)
        .inFilter('status', ['pending', 'accepted', 'declined']);
    return List<Map<String, dynamic>>.from(results);
  }

  static Future<void> cancelLessonRequest(String requestId) async {
    await _client
        .from('learner_requests')
        .update({'status': 'cancelled'}).eq('id', requestId);
  }

  static Future<void> createLessonFromRequest({
    required String requestId,
    required DateTime scheduledAt,
    required double durationHours,
  }) async {
    final request = await _client
        .from('learner_requests')
        .select()
        .eq('id', requestId)
        .maybeSingle();
    if (request == null) return;

    final normalizedDuration = durationHours.isNaN || durationHours.isInfinite
        ? 1.0
        : durationHours.toDouble();

    await _client.from('lessons').insert({
      'learner_id': request['learner_id'],
      'instructor_id': request['instructor_id'],
      'scheduled_at': scheduledAt.toIso8601String(),
      'duration_hours': _durationHoursToInt(normalizedDuration),
      'focus': request['focus'],
      'status': 'scheduled',
    });
  }

  static Future<List<Map<String, dynamic>>> getActiveLearnersWithAvailability(
      String instructorId) async {
    final results = await _client
        .from('learner_requests')
        .select(
            'learner_id, status, requested_first_name, requested_last_name, requested_profile_url, learner_profile:learner_profiles!learner_requests_learner_id_fkey(account_type, ward_first_name, ward_last_name, ward_age, ward_gender, weekly_availability, availability_recurring, learning_focus, preferred_locations, profile:profiles!learner_profiles_profile_id_fkey(id, first_name, last_name, email, phone, profile_image_url, city, gender, age))')
        .eq('instructor_id', instructorId)
        .inFilter('status', ['accepted', 'active', 'in_progress']).order(
            'created_at',
            ascending: false);

    final rawEntries = List<Map<String, dynamic>>.from(results);
    final entries = await _hydrateLessonRequests(rawEntries);
    final learners = <String, Map<String, dynamic>>{};
    for (final entry in entries) {
      final learnerId = entry['learner_id'] as String?;
      if (learnerId == null || learnerId.isEmpty) continue;
      learners.putIfAbsent(learnerId, () => Map<String, dynamic>.from(entry));
    }

    if (learners.isEmpty) return const [];

    final ids = learners.keys.toList();
    final availabilityRows = await _client
        .from('learner_profiles')
        .select(
            'profile_id, weekly_availability, availability_recurring, learning_focus, preferred_locations')
        .inFilter('profile_id', ids);

    final availabilityMap = <String, Map<String, dynamic>>{};
    for (final row in availabilityRows) {
      final id = row['profile_id'] as String?;
      if (id != null) {
        availabilityMap[id] = Map<String, dynamic>.from(row);
      }
    }

    for (final entry in learners.entries) {
      final availability = availabilityMap[entry.key];
      if (availability != null) {
        entry.value['weekly_availability'] =
            _normalizeWeeklyAvailabilityPayload(
          availability['weekly_availability'],
        );
        entry.value['availability_recurring'] =
            availability['availability_recurring'];
        entry.value['learning_focus'] ??= availability['learning_focus'];
        entry.value['preferred_locations'] ??=
            availability['preferred_locations'];
      }
    }

    return learners.values.toList();
  }

  static Future<List<Map<String, dynamic>>> getUpcomingLessonsForInstructor(
    String userId,
  ) async {
    final nowLocal = DateTime.now();
    // Include all of today's lessons plus anything upcoming, so active/in-progress
    // sessions that started earlier in the day still appear.
    final windowStart =
        DateTime(nowLocal.year, nowLocal.month, nowLocal.day).toUtc();
    final results = await _client
        .from('lessons')
        .select(
            'id, scheduled_at, start_time, end_time, duration_hours, focus, pickup_location, notes, status, learner_id, learner:profiles!lessons_learner_id_fkey(id, first_name, last_name, email, profile_image_url, city)')
        .eq('instructor_id', userId)
        .inFilter('status', ['scheduled', 'active', 'in_progress'])
        .gte('scheduled_at', windowStart.toIso8601String())
        .order('scheduled_at', ascending: true)
        .limit(20);
    final rows = List<Map<String, dynamic>>.from(results);
    return _hydrateLessonLearners(rows);
  }

  static Future<List<Map<String, dynamic>>> getInstructorLessonsForRange({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final startUtc = start.toUtc();
    final endUtc = end.toUtc();
    final results = await _client
        .from('lessons')
        .select(
            'id, scheduled_at, status, duration_hours, start_time, end_time, focus, pickup_location, notes, learner_id, started_at, ended_at, completed_by, learner:profiles!lessons_learner_id_fkey(id, first_name, last_name, email, profile_image_url, city)')
        .eq('instructor_id', userId)
        .inFilter('status', ['scheduled', 'active', 'in_progress'])
        .gte('scheduled_at', startUtc.toIso8601String())
        .lt('scheduled_at', endUtc.toIso8601String())
        .order('scheduled_at', ascending: true);
    final rows = List<Map<String, dynamic>>.from(results);
    return _hydrateLessonLearners(rows);
  }

  static Future<List<Map<String, dynamic>>> getInstructorBookingsHistory({
    required String userId,
    int limit = 200,
  }) async {
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final results = await _client
        .from('lessons')
        .select(
            'id, scheduled_at, status, duration_hours, start_time, end_time, focus, pickup_location, notes, learner_id, learner:profiles!lessons_learner_id_fkey(id, first_name, last_name, email, profile_image_url, city)')
        .eq('instructor_id', userId)
        .lt('scheduled_at', nowUtc)
        .order('scheduled_at', ascending: false)
        .limit(limit);
    final rows = List<Map<String, dynamic>>.from(results);
    return _hydrateLessonLearners(rows);
  }

  static Future<Map<String, dynamic>> getInstructorEarningsSummary(
      String instructorId) async {
    // Count scheduled and in-progress lessons as part of the month's workload,
    // while earnings only accumulate from completed/done/finished rows.
    final earningStatuses = ['completed', 'done', 'finished'];
    final lessonCountStatuses = [
      'scheduled',
      'active',
      'in_progress',
      ...earningStatuses
    ];
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).toUtc();
    final nextMonth = DateTime(now.year, now.month + 1, 1).toUtc();

    Map<String, dynamic>? instructorProfile;
    try {
      final profileRow = await _client
          .from('instructor_profiles')
          .select('default_rate, offering_rates')
          .eq('profile_id', instructorId)
          .maybeSingle();
      if (profileRow != null && profileRow is Map) {
        instructorProfile = Map<String, dynamic>.from(profileRow as Map);
      }
    } catch (_) {}

    double _deriveRate(String? focus) {
      double? asDouble(dynamic value) {
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value);
        return null;
      }

      final normalizedFocus =
          focus?.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final offeringRates =
          instructorProfile?['offering_rates'] is Map<String, dynamic>
              ? Map<String, dynamic>.from(
                  instructorProfile!['offering_rates'] as Map)
              : const <String, dynamic>{};

      if (normalizedFocus != null && normalizedFocus.isNotEmpty) {
        for (final entry in offeringRates.entries) {
          final key = entry.key.toString().toLowerCase().replaceAll(
                RegExp(r'[^a-z0-9]'),
                '',
              );
          if (key == normalizedFocus) {
            final rate = asDouble(entry.value);
            if (rate != null && rate > 0) return rate;
          }
        }
      }

      final defaultRate = asDouble(instructorProfile?['default_rate']);
      if (defaultRate != null && defaultRate > 0) return defaultRate;

      // Fallback hourly rate when no cost/default is set.
      return 45.0;
    }

    Future<List<dynamic>> fetchLessons({
      required List<String> statuses,
      DateTime? start,
      DateTime? end,
    }) async {
      var query = _client
          .from('lessons')
          .select('cost, scheduled_at, status, duration_hours, focus')
          .eq('instructor_id', instructorId);
      if (statuses.isNotEmpty) {
        query = query.inFilter('status', statuses);
      }
      if (start != null) {
        query = query.gte('scheduled_at', start.toIso8601String());
      }
      if (end != null) {
        query = query.lt('scheduled_at', end.toIso8601String());
      }
      final response = await query;
      return List<dynamic>.from(response);
    }

    double sumCost(Iterable<dynamic> rows) {
      var total = 0.0;
      for (final row in rows) {
        if (row is Map) {
          final cost = (row['cost'] as num?)?.toDouble() ?? 0;
          total += cost;
        }
      }
      return total;
    }

    int countLessons(Iterable<dynamic> rows) {
      var count = 0;
      for (final row in rows) {
        if (row is Map) {
          count += 1;
        }
      }
      return count;
    }

    double sumHours(Iterable<dynamic> rows) {
      var total = 0.0;
      for (final row in rows) {
        if (row is! Map) continue;
        final hours = (row['duration_hours'] as num?)?.toDouble();
        if (hours != null && hours > 0) {
          total += hours;
        } else {
          total += 1.0;
        }
      }
      return total;
    }

    double sumEarnings(Iterable<dynamic> rows) {
      var total = 0.0;
      for (final row in rows) {
        if (row is! Map) continue;
        final cost = (row['cost'] as num?)?.toDouble();
        if (cost != null && cost > 0) {
          total += cost;
          continue;
        }
        final focus = row['focus']?.toString();
        final durationHours =
            (row['duration_hours'] as num?)?.toDouble() ?? 1.0;
        final rate = _deriveRate(focus);
        total += rate * (durationHours <= 0 ? 1.0 : durationHours);
      }
      return total;
    }

    try {
      final monthlyLessonRows = await fetchLessons(
        statuses: lessonCountStatuses,
        start: monthStart,
        end: nextMonth,
      );
      final totalLessonRows = await fetchLessons(
        statuses: lessonCountStatuses,
      );

      // For display, treat earnings as upcoming + completed sessions for the month.
      // If a lesson has an explicit cost, we use it; otherwise we derive from rate.
      final monthlyEarnings = sumEarnings(monthlyLessonRows);
      final monthlyClasses = countLessons(monthlyLessonRows);
      final totalClasses = countLessons(totalLessonRows);
      final totalHours = sumHours(totalLessonRows);

      return {
        'monthlyEarnings': monthlyEarnings,
        'monthlyClasses': monthlyClasses,
        'totalClasses': totalClasses,
        'totalHours': totalHours,
      };
    } catch (error) {
      print('Error fetching instructor earnings summary: $error');
      return const {
        'monthlyEarnings': 0.0,
        'monthlyClasses': 0,
        'totalClasses': 0,
        'totalHours': 0.0,
      };
    }
  }

  static Future<void> replaceInstructorWeeklySchedule({
    required String instructorId,
    required DateTime weekStart,
    required List<Map<String, dynamic>> slots,
  }) async {
    final startOfWeek =
        DateTime(weekStart.year, weekStart.month, weekStart.day);
    final startUtc = startOfWeek.toUtc();
    final endUtc = startUtc.add(const Duration(days: 7));

    await _client
        .from('lessons')
        .delete()
        .eq('instructor_id', instructorId)
        .eq('status', 'scheduled')
        .gte('scheduled_at', startUtc.toIso8601String())
        .lt('scheduled_at', endUtc.toIso8601String());

    if (slots.isEmpty) {
      return;
    }

    final payload = slots.map((slot) {
      final scheduledAt = slot['scheduled_at'];
      final DateTime scheduled = scheduledAt is DateTime
          ? scheduledAt
          : DateTime.parse(scheduledAt.toString());
      double durationHours;
      final rawHours = slot['duration_hours'];
      if (rawHours is num) {
        durationHours = rawHours.toDouble();
      } else if (slot['duration_minutes'] is num) {
        durationHours = (slot['duration_minutes'] as num).toDouble() / 60.0;
      } else {
        durationHours = 1.0;
      }
      if (durationHours <= 0) {
        durationHours = 0.25;
      }
      final map = <String, dynamic>{
        'learner_id': slot['learner_id'],
        'instructor_id': instructorId,
        'scheduled_at': scheduled.toUtc().toIso8601String(),
        'start_time': slot['start_time'],
        'end_time': slot['end_time'],
        'duration_hours': _durationHoursToInt(durationHours),
        'cost': slot['cost'] ?? 0,
        'status': 'scheduled',
        'focus': slot['focus'] ?? 'Weekly schedule',
        'notes': slot['notes'],
      };
      map.removeWhere((_, value) => value == null);
      return map;
    }).toList();

    if (payload.isEmpty) return;
    await _client.from('lessons').insert(payload);
  }

  static Future<Map<String, Map<String, dynamic>>> getProfileSummaries(
      List<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await _client
        .from('profiles')
        .select('id, first_name, last_name, email, profile_image_url')
        .inFilter('id', ids);
    final map = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final id = row['id'] as String?;
      if (id != null) {
        map[id] = Map<String, dynamic>.from(row);
      }
    }
    return map;
  }

  static Future<void> releaseLearnerFromInstructor({
    required String instructorId,
    required String learnerId,
  }) async {
    await _client
        .from('learner_requests')
        .update({'status': 'removed'})
        .eq('instructor_id', instructorId)
        .eq('learner_id', learnerId)
        .neq('status', 'removed');

    await _client
        .from('lessons')
        .update({'status': 'cancelled'})
        .eq('instructor_id', instructorId)
        .eq('learner_id', learnerId)
        .eq('status', 'scheduled');
  }

  // Instructor Methods
  static Future<List<InstructorModel>> getInstructors({
    String? city,
    double? latitude,
    double? longitude,
    double radius = 10.0, // km
    String? carType,
    String? transmissionType,
    double? minRating,
  }) async {
    try {
      var query =
          _client.from('instructor_profiles').select('*, user:profiles(*)');

      final targetCity = city?.trim().toLowerCase();
      String? _normalizedCity(dynamic value) {
        if (value is String) {
          final trimmed = value.trim();
          return trimmed.isEmpty ? null : trimmed.toLowerCase();
        }
        return null;
      }

      if (minRating != null) {
        query = query.gte('rating', minRating);
      }

      if (carType != null) {
        query = query.contains('car_types', [carType]);
      }

      if (transmissionType != null) {
        query = query.contains('transmission_types', [transmissionType]);
      }

      final response = await query;
      final rows = response.whereType<Map<String, dynamic>>().toList();

      final instructors = <InstructorModel>[];

      for (final row in rows) {
        Map<String, dynamic>? userJson = row['user'] as Map<String, dynamic>?;
        if (userJson == null) {
          final profileId = (row['profile_id'] ?? row['id'])?.toString();
          if (profileId != null && profileId.isNotEmpty) {
            try {
              final fallback = await _client
                  .from('profiles')
                  .select(
                      'id, email, phone, first_name, last_name, role, profile_image_url, city, created_at, updated_at, is_verified')
                  .eq('id', profileId)
                  .maybeSingle();
              if (fallback is Map<String, dynamic>) {
                userJson = fallback;
                row['user'] = fallback;
              }
            } catch (_) {
              // ignore fallback failures and continue
            }
          }
        }

        if (row['user'] is Map<String, dynamic>) {
          if (targetCity != null && targetCity.isNotEmpty) {
            final candidate = _normalizedCity((row['user'] as Map)['city']);
            if (candidate != targetCity) {
              continue;
            }
          }
          instructors.add(InstructorModel.fromJson(row));
        } else {
          final profileId = (row['profile_id'] ?? row['id'])?.toString();
          if (profileId != null && profileId.isNotEmpty) {
            final nowIso = DateTime.now().toIso8601String();
            row['user'] = {
              'id': profileId,
              'email': (row['contact_email'] as String?) ?? '',
              'phone': row['contact_phone'],
              'first_name':
                  (row['display_name'] as String?) ?? 'Drive Tutor Instructor',
              'last_name': '',
              'role': 'instructor',
              'profile_image_url': row['profile_image_url'],
              'created_at': nowIso,
              'updated_at': nowIso,
              'is_verified': row['is_verified'] ?? false,
              'city': row['city'],
            };
            if (targetCity != null && targetCity.isNotEmpty) {
              final candidate = _normalizedCity(row['city']);
              if (candidate != targetCity) {
                continue;
              }
            }
            instructors.add(InstructorModel.fromJson(row));
          }
        }
      }

      // Filter by distance if coordinates provided
      if (latitude != null && longitude != null) {
        final filtered = instructors.where((instructor) {
          final distance = _calculateDistance(
            latitude,
            longitude,
            instructor.latitude,
            instructor.longitude,
          );
          return distance <= radius;
        }).toList();
        return filtered;
      }

      return instructors;
    } catch (e) {
      print('Error fetching instructors: $e');
      return [];
    }
  }

  static Future<InstructorModel?> getInstructor(String instructorId) async {
    try {
      final response = await _client
          .from('instructor_profiles')
          .select('*, user:profiles(*)')
          .eq('profile_id', instructorId)
          .single();

      return InstructorModel.fromJson(response);
    } catch (e) {
      print('Error fetching instructor: $e');
      return null;
    }
  }

  // Lesson Methods
  static Future<List<LessonModel>> getLessons(String learnerId) async {
    try {
      final response = await _client
          .from('lessons')
          .select('*, instructor:instructor_profiles(*, user:profiles(*))')
          .eq('learner_id', learnerId)
          .order('scheduled_at', ascending: true);

      final lessons = <LessonModel>[];
      for (final row in response) {
        final json = Map<String, dynamic>.from(row);
        final lessonId = json['id']?.toString() ?? '<unknown>';
        final instructor = json['instructor'];
        if (instructor is! Map) {
          print(
            'Skipping malformed lesson $lessonId: missing instructor join.',
          );
          continue;
        }

        final instructorMap = Map<String, dynamic>.from(instructor);
        final user = instructorMap['user'];
        if (user is! Map) {
          print(
            'Skipping malformed lesson $lessonId: missing instructor user join.',
          );
          continue;
        }

        try {
          final lesson = LessonModel.fromJson({
            ...json,
            'instructor': {
              ...instructorMap,
              'user': Map<String, dynamic>.from(user),
            },
          });
          lessons.add(
            lesson.effectiveStatus == lesson.status
                ? lesson
                : lesson.copyWith(status: lesson.effectiveStatus),
          );
        } catch (parseError) {
          print('Skipping malformed lesson $lessonId: $parseError');
        }
      }

      return lessons;
    } catch (e) {
      print('Error fetching lessons: $e');
      return [];
    }
  }

  static Future<LessonModel?> createLesson({
    required String learnerId,
    required String instructorId,
    required DateTime scheduledDate,
    required String startTime,
    required String endTime,
    required double duration,
    required double cost,
    String? notes,
    String? location,
    String? focus,
    DateTime? lessonDate,
  }) async {
    try {
      final response = await _client
          .from('lessons')
          .insert({
            'learner_id': learnerId,
            'instructor_id': instructorId,
            'scheduled_at': scheduledDate.toIso8601String(),
            'start_time': startTime,
            'end_time': endTime,
            'duration_hours': _durationHoursToInt(duration),
            'cost': cost,
            'notes': notes,
            'pickup_location': location,
            if (focus != null) 'focus': focus,
            if (lessonDate != null)
              'lesson_date': DateTime(
                lessonDate.year,
                lessonDate.month,
                lessonDate.day,
              ).toIso8601String(),
            'status': 'scheduled',
          })
          .select('*, instructor:instructor_profiles(*, user:profiles(*))')
          .single();

      return LessonModel.fromJson(response);
    } catch (e) {
      print('Error creating lesson: $e');
      return null;
    }
  }

  static Future<LessonModel?> updateLessonStatus(
    String lessonId,
    String status, {
    DateTime? startedAt,
    DateTime? endedAt,
    String? completedBy,
  }) async {
    try {
      final payload = <String, dynamic>{'status': status};
      if (startedAt != null) {
        payload['started_at'] = startedAt.toUtc().toIso8601String();
      }
      if (endedAt != null) {
        payload['ended_at'] = endedAt.toUtc().toIso8601String();
      }
      if (completedBy != null) {
        payload['completed_by'] = completedBy;
      }
      final response = await _client
          .from('lessons')
          .update(payload)
          .eq('id', lessonId)
          .select('*, instructor:instructor_profiles(*, user:profiles(*))')
          .single();

      return LessonModel.fromJson(response);
    } catch (e) {
      print('Error updating lesson status: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> updateInstructorLessonStatus({
    required String lessonId,
    required String status,
    DateTime? startedAt,
    DateTime? endedAt,
    String? completedBy,
  }) async {
    try {
      final payload = <String, dynamic>{'status': status};
      if (startedAt != null) {
        payload['started_at'] = startedAt.toUtc().toIso8601String();
      }
      if (endedAt != null) {
        payload['ended_at'] = endedAt.toUtc().toIso8601String();
      }
      if (completedBy != null) {
        payload['completed_by'] = completedBy;
      }

      final response = await _client
          .from('lessons')
          .update(payload)
          .eq('id', lessonId)
          .select(
              'id, scheduled_at, status, duration_hours, start_time, end_time, focus, pickup_location, notes, learner_id, started_at, ended_at, completed_by, learner:profiles!lessons_learner_id_fkey(id, first_name, last_name, email, profile_image_url, city)')
          .single();

      final rows = await _hydrateLessonLearners([
        Map<String, dynamic>.from(response),
      ]);
      return rows.isEmpty ? Map<String, dynamic>.from(response) : rows.first;
    } catch (e) {
      print('Error updating instructor lesson status: $e');
      return null;
    }
  }

  static Future<LessonModel?> updateScheduledLesson({
    required String lessonId,
    required DateTime scheduledDate,
    required String startTime,
    required String endTime,
    required double duration,
    double? cost,
    String? notes,
    String? location,
    String? focus,
    DateTime? lessonDate,
  }) async {
    try {
      final payload = <String, dynamic>{
        'scheduled_at': scheduledDate.toIso8601String(),
        'start_time': startTime,
        'end_time': endTime,
        'duration_hours': _durationHoursToInt(duration),
        if (cost != null) 'cost': cost,
        if (notes != null) 'notes': notes,
        if (location != null) 'pickup_location': location,
        if (focus != null) 'focus': focus,
        if (lessonDate != null)
          'lesson_date': DateTime(
            lessonDate.year,
            lessonDate.month,
            lessonDate.day,
          ).toIso8601String(),
      };

      final response = await _client
          .from('lessons')
          .update(payload)
          .eq('id', lessonId)
          .select('*, instructor:instructor_profiles(*, user:profiles(*))')
          .single();

      return LessonModel.fromJson(response);
    } catch (e) {
      print('Error updating scheduled lesson: $e');
      return null;
    }
  }

  static Future<int> getMonthlyCancellationCount({
    required String userId,
    required bool isInstructor,
    DateTime? asOf,
  }) async {
    final now = asOf ?? DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).toUtc();
    final nextMonth = DateTime(now.year, now.month + 1, 1).toUtc();
    final column = isInstructor ? 'instructor_id' : 'learner_id';

    final response = await _client
        .from('lessons')
        .select('id')
        .eq(column, userId)
        .eq('status', 'cancelled')
        .gte('updated_at', monthStart.toIso8601String())
        .lt('updated_at', nextMonth.toIso8601String());

    if (response is List) {
      return response.length;
    }
    return 0;
  }

  static Future<Map<String, dynamic>?> updateLessonDetails({
    required String lessonId,
    DateTime? scheduledAt,
    DateTime? lessonDate,
    String? startTime,
    String? endTime,
    String? focus,
    String? pickupLocation,
    String? notes,
    double? cost,
    Map<String, dynamic>? additionalFields,
  }) async {
    final payload = <String, dynamic>{};
    if (scheduledAt != null) {
      payload['scheduled_at'] = scheduledAt.toUtc().toIso8601String();
    }
    if (lessonDate != null) {
      final dateOnly = DateTime.utc(
        lessonDate.year,
        lessonDate.month,
        lessonDate.day,
      );
      payload['lesson_date'] = dateOnly.toIso8601String();
    }
    if (startTime != null) payload['start_time'] = startTime;
    if (endTime != null) payload['end_time'] = endTime;
    if (focus != null) payload['focus'] = focus;
    if (pickupLocation != null) payload['pickup_location'] = pickupLocation;
    if (notes != null) payload['notes'] = notes;
    if (cost != null) payload['cost'] = cost;
    if (additionalFields != null) {
      payload.addAll(additionalFields);
    }
    if (payload.isEmpty) return null;

    try {
      final response = await _client
          .from('lessons')
          .update(payload)
          .eq('id', lessonId)
          .select('*, learner:profiles!lessons_learner_id_fkey(*)')
          .maybeSingle();
      if (response == null) return null;
      return Map<String, dynamic>.from(response);
    } catch (e) {
      print('Error updating lesson details: $e');
      return null;
    }
  }

  // Helper Methods
  static int _durationHoursToInt(double value) {
    if (value.isNaN || value.isInfinite) return 1;
    final normalized = value <= 0 ? 1.0 : value;
    final ceiled = normalized.ceil();
    return ceiled < 1 ? 1 : ceiled;
  }

  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = (dLat / 2) * (dLat / 2) +
        (dLon / 2) *
            (dLon / 2) *
            (lat1 * 3.14159 / 180) *
            (lat2 * 3.14159 / 180);

    final double c = 2 * math.sqrt(a);
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (3.14159 / 180);
  }
}
