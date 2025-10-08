import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding/role_selection_screen.dart';
import '../screens/onboarding/verification_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/instructor/find_instructor_screen.dart';
import '../screens/booking/booking_screen.dart';
import '../screens/lessons/my_lessons_screen.dart';
import '../screens/progress/progress_tracker_screen.dart';
import '../screens/profile/profile_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String roleSelection = '/role-selection';
  static const String verification = '/verification';
  static const String home = '/home';
  static const String findInstructor = '/find-instructor';
  static const String booking = '/booking';
  static const String myLessons = '/my-lessons';
  static const String progressTracker = '/progress-tracker';
  static const String profile = '/profile';

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
        path: verification,
        builder: (context, state) {
          final role = state.extra as String? ?? 'learner';
          return VerificationScreen(role: role);
        },
      ),
      GoRoute(
        path: home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: findInstructor,
        builder: (context, state) => const FindInstructorScreen(),
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
        path: progressTracker,
        builder: (context, state) => const ProgressTrackerScreen(),
      ),
      GoRoute(
        path: profile,
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
}
