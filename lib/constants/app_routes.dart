import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/lesson_model.dart';
import '../screens/booking/booking_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/instructor_home_screen.dart';
import '../screens/instructor/find_instructor_screen.dart';
import '../screens/instructor/instructor_availability_screen.dart';
import '../screens/instructor/instructor_lesson_detail_screen.dart';
import '../screens/instructor/instructor_requests_screen.dart';
import '../screens/instructor/instructor_learner_detail_screen.dart';
import '../screens/lessons/completed_lesson_detail_screen.dart';
import '../screens/lessons/my_lessons_screen.dart';
import '../screens/location/location_setup_screen.dart';
import '../screens/onboarding/auth_screen.dart';
import '../screens/onboarding/learner_questionnaire_screen.dart';
import '../screens/onboarding/instructor_questionnaire_screen.dart';
import '../screens/onboarding/learning_focus_screen.dart';
import '../screens/onboarding/license_info_screen.dart';
import '../screens/onboarding/role_selection_screen.dart';
import '../screens/onboarding/verification_screen.dart';
import '../screens/profile/help_support_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/progress/progress_tracker_screen.dart';
import '../screens/splash_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String roleSelection = '/role-selection';
  static const String auth = '/auth';
  static const String verification = '/verification';
  static const String learnerQuestionnaire = '/learner-questionnaire';
  static const String instructorQuestionnaire = '/instructor-questionnaire';
  static const String licenseInfo = '/license-info';
  static const String learningFocus = '/learning-focus';
  static const String editProfile = '/edit-profile';
  static const String home = '/home';
  static const String instructorHome = '/instructor-home';
  static const String instructorAvailability = '/instructor-availability';
  static const String instructorLessonDetail = '/instructor-lesson-detail';
  static const String instructorRequests = '/instructor-requests';
  static const String instructorLearnerDetail = '/instructor-learner-detail';
  static const String findInstructor = '/find-instructor';
  static const String booking = '/booking';
  static const String myLessons = '/my-lessons';
  static const String completedLessonDetail = '/completed-lesson-detail';
  static const String progressTracker = '/progress-tracker';
  static const String profile = '/profile';
  static const String helpSupport = '/help-support';
  static const String locationSetup = '/location-setup';

  static final GoRouter router = GoRouter(
    initialLocation: splash,
    routes: [
      GoRoute(
        path: splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: roleSelection,
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: auth,
        builder: (context, state) {
          final role = state.extra as String? ?? 'learner';
          return AuthScreen(role: role);
        },
      ),
      GoRoute(
        path: verification,
        builder: (context, state) {
          final role = state.extra as String? ?? 'learner';
          return VerificationScreen(role: role);
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
        path: learnerQuestionnaire,
        builder: (context, state) {
          final role = state.extra as String? ?? 'learner';
          return LearnerQuestionnaireScreen(role: role);
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
        path: instructorRequests,
        builder: (context, state) => const InstructorRequestsScreen(),
      ),
      GoRoute(
        path: instructorLearnerDetail,
        builder: (context, state) {
          final learner = state.extra as Map<String, dynamic>?;
          return InstructorLearnerDetailScreen(learner: learner);
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
        path: booking,
        builder: (context, state) {
          final instructorId = state.extra as String?;
          return BookingScreen(instructorId: instructorId);
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
        path: helpSupport,
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        path: locationSetup,
        builder: (context, state) => const LocationSetupScreen(),
      ),
    ],
  );
}
