import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/instructor_document_type.dart';
import '../models/learner_onboarding_draft.dart';
import '../models/lesson_model.dart';
import '../models/signup_flow_state.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/instructor_home_screen.dart';
import '../screens/learner/learner_approval_success_screen.dart';
import '../screens/instructor/find_instructor_screen.dart';
import '../screens/instructor/instructor_availability_screen.dart';
import '../screens/instructor/instructor_lesson_detail_screen.dart';
import '../screens/instructor/instructor_learner_detail_screen.dart';
import '../screens/instructor/instructor_billing_screen.dart';
import '../screens/instructor/learner_roster_detail_screen.dart';
import '../screens/instructor/instructor_profile_preview_screen.dart';
import '../screens/instructor/review_learner_request_screen.dart';
import '../screens/instructor/instructor_lesson_edit_screen.dart';
import '../screens/learner/learner_instructor_detail_screen.dart';
import '../screens/lessons/completed_lesson_detail_screen.dart';
import '../screens/lessons/my_lessons_screen.dart';
import '../screens/location/location_setup_screen.dart';
import '../screens/onboarding/auth_screen.dart';
import '../screens/onboarding/auth_redirect_screen.dart';
import '../screens/onboarding/account_entry_screen.dart';
import '../screens/onboarding/forgot_password_screen.dart';
import '../screens/onboarding/guardian_license_capture_screen.dart';
import '../screens/onboarding/guardian_selfie_capture_screen.dart';
import '../screens/onboarding/identity_license_capture_screen.dart';
import '../screens/onboarding/identity_pending_review_screen.dart';
import '../screens/onboarding/identity_selfie_capture_screen.dart';
import '../screens/onboarding/identity_verification_intro_screen.dart';
import '../screens/onboarding/intro_flow_screen.dart';
import '../screens/onboarding/instructor_invite_landing_screen.dart';
import '../screens/onboarding/instructor_credentials_portal_screen.dart';
import '../screens/onboarding/instructor_document_upload_screen.dart';
import '../screens/onboarding/learner_pickup_address_screen.dart';
import '../screens/onboarding/learner_questionnaire_screen.dart';
import '../screens/onboarding/learner_account_type_screen.dart';
import '../screens/onboarding/learner_weekly_availability_screen.dart';
import '../screens/onboarding/instructor_questionnaire_screen.dart';
import '../screens/onboarding/learning_focus_screen.dart';
import '../screens/onboarding/license_info_screen.dart';
import '../screens/onboarding/new_password_screen.dart';
import '../screens/onboarding/password_recovery_verify_screen.dart';
import '../screens/onboarding/role_selection_screen.dart';
import '../screens/onboarding/sign_up_email_screen.dart';
import '../screens/onboarding/sign_up_verify_screen.dart';
import '../screens/onboarding/verification_screen.dart';
import '../screens/profile/help_support_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../models/location_preference.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/progress/progress_tracker_screen.dart';
import '../screens/splash_screen.dart';

class AppRoutes {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String splash = '/';
  static const String intro = '/intro';
  static const String accountEntry = '/account-entry';
  static const String roleSelection = '/role-selection';
  static const String learnerAccountType = '/learner-account-type';
  static const String auth = '/auth';
  static const String authRedirect = '/auth-redirect';
  static const String verification = '/verification';
  static const String forgotPassword = '/forgot-password';
  static const String signUpEmail = '/sign-up-email';
  static const String signUpVerify = '/sign-up-verify';
  static const String passwordRecoveryVerify = '/password-recovery-verify';
  static const String newPassword = '/new-password';
  static const String identityVerificationIntro = '/identity-verification';
  static const String identityLicenseCapture = '/identity-license-capture';
  static const String identitySelfieCapture = '/identity-selfie-capture';
  static const String guardianLicenseCapture = '/guardian-license-capture';
  static const String guardianSelfieCapture = '/guardian-selfie-capture';
  static const String identityPendingReview = '/identity-pending-review';
  static const String learnerQuestionnaire = '/learner-questionnaire';
  static const String learnerPickupAddress = '/learner-pickup-address';
  static const String learnerWeeklyAvailability =
      '/learner-weekly-availability';
  static const String learnerApprovalSuccess = '/learner-approval-success';
  static const String instructorInvite = '/invite/instructor/:code';
  static const String instructorQuestionnaire = '/instructor-questionnaire';
  static const String instructorCredentialsPortal =
      '/instructor-credentials-portal';
  static const String instructorDocumentUpload = '/instructor-document-upload';
  static const String licenseInfo = '/license-info';
  static const String learningFocus = '/learning-focus';
  static const String editProfile = '/edit-profile';
  static const String editLearnerAvailability = '/learner-availability';
  static const String home = '/home';
  static const String instructorHome = '/instructor-home';
  static const String instructorBilling = '/instructor-billing';
  static const String instructorAvailability = '/instructor-availability';
  static const String instructorLessonDetail = '/instructor-lesson-detail';
  static const String instructorLessonEdit = '/instructor-lesson-edit';
  static const String instructorLearnerDetail = '/instructor-learner-detail';
  static const String instructorLearnerRosterPreview =
      '/instructor-learner-roster-preview';
  static const String instructorProfilePreview = '/instructor-profile-preview';
  static const String reviewLearnerRequest = '/review-learner-request';
  static const String learnerInstructorDetail = '/learner-instructor-detail';
  static const String findInstructor = '/find-instructor';
  static const String myLessons = '/my-lessons';
  static const String completedLessonDetail = '/completed-lesson-detail';
  static const String progressTracker = '/progress-tracker';
  static const String profile = '/profile';
  static const String helpSupport = '/help-support';
  static const String locationSetup = '/location-setup';

  static final GoRouter router = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: splash,
    routes: [
      GoRoute(
        path: splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: intro,
        builder: (context, state) => const IntroFlowScreen(),
      ),
      GoRoute(
        path: accountEntry,
        builder: (context, state) => const AccountEntryScreen(),
      ),
      GoRoute(
        path: roleSelection,
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: learnerAccountType,
        builder: (context, state) => const LearnerAccountTypeScreen(),
      ),
      GoRoute(
        path: auth,
        builder: (context, state) {
          final extra = state.extra;
          final initialEmail = extra is String
              ? extra
              : (extra is Map ? extra['email'] as String? : null);
          return AuthScreen(initialEmail: initialEmail);
        },
      ),
      GoRoute(
        path: authRedirect,
        builder: (context, state) => AuthRedirectScreen(
          flow: state.uri.queryParameters['flow'] ?? 'signup',
        ),
      ),
      GoRoute(
        path: forgotPassword,
        builder: (context, state) {
          final extra = state.extra;
          final initialEmail = extra is String
              ? extra
              : (extra is Map ? extra['email'] as String? : null);
          return ForgotPasswordScreen(initialEmail: initialEmail);
        },
      ),
      GoRoute(
        path: signUpEmail,
        builder: (context, state) {
          final extra = state.extra;
          final initialEmail = extra is String
              ? extra
              : (extra is Map ? extra['email'] as String? : null);
          return SignUpEmailScreen(
            initialEmail: initialEmail,
            role: extra is Map
                ? (extra['role'] as String? ?? 'learner')
                : 'learner',
            learnerAccountType: extra is Map
                ? (extra['learnerAccountType'] as String? ?? 'learner')
                : 'learner',
          );
        },
      ),
      GoRoute(
        path: passwordRecoveryVerify,
        builder: (context, state) {
          final extra = state.extra;
          final email = extra is String
              ? extra
              : (extra is Map ? extra['email'] as String? : null);
          return PasswordRecoveryVerifyScreen(email: email ?? '');
        },
      ),
      GoRoute(
        path: signUpVerify,
        builder: (context, state) {
          final extra = state.extra;
          final flowState = extra is Map<String, dynamic>
              ? SignupFlowState.fromMap(extra)
              : const SignupFlowState(
                  email: '',
                  authUserId: '',
                  flowToken: '',
                );
          return SignUpVerifyScreen(flowState: flowState);
        },
      ),
      GoRoute(
        path: newPassword,
        builder: (context, state) {
          final extra = state.extra;
          final email = extra is String
              ? extra
              : (extra is Map ? extra['email'] as String? : null);
          final authUserId =
              extra is Map ? extra['authUserId'] as String? : null;
          final flowToken = extra is Map ? extra['flowToken'] as String? : null;
          final role = extra is Map ? extra['role'] as String? : null;
          final learnerAccountType =
              extra is Map ? extra['learnerAccountType'] as String? : null;
          final flow = extra is Map
              ? (extra['flow'] as String? ?? 'recovery')
              : 'recovery';
          return NewPasswordScreen(
            email: email,
            authUserId: authUserId,
            flowToken: flowToken,
            role: role,
            learnerAccountType: learnerAccountType,
            flow: flow,
          );
        },
      ),
      GoRoute(
        path: identityVerificationIntro,
        builder: (context, state) {
          final extra = state.extra;
          final role = extra is String
              ? extra
              : (extra is Map ? (extra['role'] as String?) : null);
          return IdentityVerificationIntroScreen(role: role ?? 'learner');
        },
      ),
      GoRoute(
        path: identityLicenseCapture,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? const {};
          return IdentityLicenseCaptureScreen(
            role: (extra['role'] as String?) ?? 'learner',
            licenseImagePath: extra['licenseImagePath'] as String?,
          );
        },
      ),
      GoRoute(
        path: identitySelfieCapture,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? const {};
          return IdentitySelfieCaptureScreen(
            role: (extra['role'] as String?) ?? 'learner',
            licenseImagePath: extra['licenseImagePath'] as String?,
            selfieImagePath: extra['selfieImagePath'] as String?,
          );
        },
      ),
      GoRoute(
        path: guardianLicenseCapture,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? const {};
          return GuardianLicenseCaptureScreen(
            role: (extra['role'] as String?) ?? 'learner',
            licenseImagePath: extra['licenseImagePath'] as String? ?? '',
            selfieImagePath: extra['selfieImagePath'] as String? ?? '',
            guardianLicenseImagePath:
                extra['guardianLicenseImagePath'] as String?,
          );
        },
      ),
      GoRoute(
        path: guardianSelfieCapture,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? const {};
          return GuardianSelfieCaptureScreen(
            role: (extra['role'] as String?) ?? 'learner',
            licenseImagePath: extra['licenseImagePath'] as String? ?? '',
            selfieImagePath: extra['selfieImagePath'] as String? ?? '',
            guardianLicenseImagePath:
                extra['guardianLicenseImagePath'] as String? ?? '',
            guardianSelfieImagePath:
                extra['guardianSelfieImagePath'] as String?,
          );
        },
      ),
      GoRoute(
        path: identityPendingReview,
        builder: (context, state) {
          final rawExtra = state.extra;
          final extra = rawExtra is Map<String, dynamic> ? rawExtra : const {};
          final role = rawExtra is String
              ? rawExtra
              : (extra['role'] as String?) ?? 'learner';
          return IdentityPendingReviewScreen(
            role: role,
            licenseImagePath: extra['licenseImagePath'] as String?,
            selfieImagePath: extra['selfieImagePath'] as String?,
          );
        },
      ),
      GoRoute(
        path: verification,
        builder: (context, state) {
          final extra = state.extra;
          var role = 'learner';
          String? phoneNumber;
          String? nextRoute;

          if (extra is String) {
            role = extra;
          } else if (extra is Map) {
            role = (extra['role'] as String?) ?? role;
            phoneNumber = extra['phoneNumber'] as String?;
            nextRoute = extra['nextRoute'] as String?;
          }

          return VerificationScreen(
            role: role,
            phoneNumber: phoneNumber,
            nextRoute: nextRoute,
          );
        },
      ),
      GoRoute(
        path: licenseInfo,
        builder: (context, state) {
          final extra = state.extra;
          String role = 'learner';
          String? initialLicenceNumber;
          DateTime? initialLicenceExpiry;
          Map<String, dynamic>? questionnaire;

          if (extra is String) {
            role = extra;
          } else if (extra is Map) {
            role = (extra['role'] as String?) ?? role;
            final licenceNumber = extra['initialLicenceNumber'] as String?;
            final licenceExpiryIso = extra['initialLicenceExpiry'] as String?;
            final questionnaireMap = extra['questionnaire'];

            if (licenceNumber != null) {
              initialLicenceNumber = licenceNumber;
            }

            if (licenceExpiryIso is String) {
              initialLicenceExpiry = DateTime.tryParse(licenceExpiryIso);
            }

            if (questionnaireMap is Map<String, dynamic>) {
              questionnaire = questionnaireMap;
            }
          }

          return LicenseInfoScreen(
            role: role,
            initialLicenceNumber: initialLicenceNumber,
            initialLicenceExpiry: initialLicenceExpiry,
            questionnaireData: questionnaire,
          );
        },
      ),
      GoRoute(
        path: instructorCredentialsPortal,
        builder: (context, state) => const InstructorCredentialsPortalScreen(),
      ),
      GoRoute(
        path: instructorDocumentUpload,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? const {};
          final type = InstructorDocumentType.fromName(
            extra['documentType'] as String?,
          );
          return InstructorDocumentUploadScreen(
            documentType: type ?? InstructorDocumentType.insuranceDocument,
          );
        },
      ),
      GoRoute(
        path: learnerQuestionnaire,
        builder: (context, state) {
          final extra = state.extra;
          final queryAccountType =
              state.uri.queryParameters['accountType']?.trim();
          final draft = extra is LearnerOnboardingDraft
              ? extra
              : LearnerOnboardingDraft(
                  role: extra as String? ?? 'learner',
                  learnerAccountType: queryAccountType?.isNotEmpty == true
                      ? queryAccountType!
                      : 'learner',
                );
          return LearnerQuestionnaireScreen(initialDraft: draft);
        },
      ),
      GoRoute(
        path: learnerPickupAddress,
        builder: (context, state) {
          final draft = state.extra is LearnerOnboardingDraft
              ? state.extra as LearnerOnboardingDraft
              : const LearnerOnboardingDraft();
          return LearnerPickupAddressScreen(draft: draft);
        },
      ),
      GoRoute(
        path: learnerWeeklyAvailability,
        builder: (context, state) {
          final draft = state.extra is LearnerOnboardingDraft
              ? state.extra as LearnerOnboardingDraft
              : const LearnerOnboardingDraft();
          return LearnerWeeklyAvailabilityScreen(draft: draft);
        },
      ),
      GoRoute(
        path: learnerApprovalSuccess,
        builder: (context, state) {
          final extra = state.extra;
          final approvalToken = extra is String
              ? extra
              : (extra is Map ? extra['approvalToken'] as String? : null);
          return LearnerApprovalSuccessScreen(
            approvalToken: approvalToken,
          );
        },
      ),
      GoRoute(
        path: instructorInvite,
        builder: (context, state) {
          final code = state.pathParameters['code'] ?? '';
          return InstructorInviteLandingScreen(code: code);
        },
      ),
      GoRoute(
        path: instructorQuestionnaire,
        builder: (context, state) {
          final role = state.extra as String? ?? 'instructor';
          return InstructorQuestionnaireScreen(role: role);
        },
      ),
      GoRoute(
        path: learningFocus,
        builder: (context, state) {
          final role = state.extra as String? ?? 'learner';
          return LearningFocusScreen(role: role);
        },
      ),
      GoRoute(
        path: home,
        builder: (context, state) {
          final extras = state.extra;
          String? focus;
          String? location;
          if (extras is Map) {
            focus = extras['focus'] as String?;
            location = extras['location'] as String?;
          }
          return HomeScreen(initialFocus: focus, initialLocation: location);
        },
      ),
      GoRoute(
        path: instructorHome,
        builder: (context, state) => const InstructorHomeScreen(),
      ),
      GoRoute(
        path: instructorBilling,
        builder: (context, state) => const InstructorBillingScreen(),
      ),
      GoRoute(
        path: instructorAvailability,
        builder: (context, state) => const InstructorAvailabilityScreen(),
      ),
      GoRoute(
        path: instructorLessonDetail,
        builder: (context, state) {
          final lesson = state.extra as Map<String, dynamic>?;
          return InstructorLessonDetailScreen(lesson: lesson);
        },
      ),
      GoRoute(
        path: instructorLessonEdit,
        builder: (context, state) {
          final lesson = state.extra as Map<String, dynamic>? ?? const {};
          return InstructorLessonEditScreen(lesson: lesson);
        },
      ),
      GoRoute(
        path: instructorLearnerRosterPreview,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? const {};
          final learner =
              (extra['learner'] as Map<String, dynamic>?) ?? const {};
          final availabilityLines =
              (extra['availability'] as List?)?.whereType<String>().toList();
          final summary =
              (extra['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
          final onViewProfile = extra['onViewProfile'] as VoidCallback?;
          final onRemoveLearner =
              extra['onRemoveLearner'] as Future<bool> Function(BuildContext)?;
          return InstructorLearnerRosterPreviewScreen(
            learner: learner,
            availabilityLines: availabilityLines,
            summary: summary,
            onViewProfile: onViewProfile,
            onRemoveLearner: onRemoveLearner,
          );
        },
      ),
      GoRoute(
        path: instructorLearnerDetail,
        builder: (context, state) {
          final learner = state.extra as Map<String, dynamic>?;
          return InstructorLearnerDetailScreen(learner: learner);
        },
      ),
      GoRoute(
        path: instructorProfilePreview,
        builder: (context, state) {
          final profile = state.extra as Map<String, dynamic>? ?? const {};
          return InstructorProfilePreviewScreen(profile: profile);
        },
      ),
      GoRoute(
        path: reviewLearnerRequest,
        builder: (context, state) {
          final request = state.extra as Map<String, dynamic>?;
          return ReviewLearnerRequestScreen(request: request);
        },
      ),
      GoRoute(
        path: learnerInstructorDetail,
        builder: (context, state) {
          final profile = state.extra as Map<String, dynamic>? ?? const {};
          return LearnerInstructorDetailScreen(profile: profile);
        },
      ),
      GoRoute(
        path: findInstructor,
        builder: (context, state) {
          final focus = state.extra as String?;
          return FindInstructorScreen(selectedFocus: focus);
        },
      ),
      GoRoute(
        path: myLessons,
        builder: (context, state) => const MyLessonsScreen(),
      ),
      GoRoute(
        path: completedLessonDetail,
        builder: (context, state) {
          final lesson = state.extra as LessonModel?;
          if (lesson == null) {
            return const Scaffold(
              body: Center(child: Text('Lesson information unavailable.')),
            );
          }
          return CompletedLessonDetailScreen(lesson: lesson);
        },
      ),
      GoRoute(
        path: progressTracker,
        builder: (context, state) => const ProgressTrackerScreen(),
      ),
      GoRoute(
        path: profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: editLearnerAvailability,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? const {};
          final rawAvailability =
              extra['initialAvailability'] as Map<String, dynamic>? ??
                  const <String, dynamic>{};
          final initialAvailability = <String, List<String>>{
            for (final entry in rawAvailability.entries)
              entry.key: entry.value is List
                  ? List<String>.from(entry.value as List)
                  : const <String>[],
          };
          return LearnerWeeklyAvailabilityScreen(
            initialAvailability: initialAvailability,
            availabilityRecurring:
                (extra['availabilityRecurring'] as bool?) ?? true,
            isProfileEdit: true,
          );
        },
      ),
      GoRoute(
        path: helpSupport,
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: locationSetup,
        builder: (context, state) {
          final args = state.extra as LocationSetupArgs?;
          return LocationSetupScreen(
            savedLocations: args?.savedLocations ?? const [],
            initialSelectionKey: args?.initialSelectionKey,
            initialManualAddress: args?.initialManualAddress,
          );
        },
      ),
    ],
  );
}
