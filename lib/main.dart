import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'constants/app_theme.dart';
import 'constants/app_routes.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var dotenvLoaded = false;
  if (!kReleaseMode) {
    try {
      await dotenv.load();
      dotenvLoaded = true;
    } catch (_) {
      // Local builds should prefer --dart-define. A missing .env is acceptable.
    }
  }

  const definedSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const definedSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  final envSupabaseUrl = dotenvLoaded ? dotenv.env['SUPABASE_URL'] : null;
  final envSupabaseAnonKey =
      dotenvLoaded ? dotenv.env['SUPABASE_ANON_KEY'] : null;
  final supabaseUrl =
      definedSupabaseUrl.isNotEmpty ? definedSupabaseUrl : envSupabaseUrl;
  final supabaseAnonKey = definedSupabaseAnonKey.isNotEmpty
      ? definedSupabaseAnonKey
      : envSupabaseAnonKey;

  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw StateError(
      'Missing Supabase configuration. Pass SUPABASE_URL and '
      'SUPABASE_ANON_KEY with --dart-define.',
    );
  }

  await Firebase.initializeApp();

  // Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  await PushNotificationService.initialize();

  runApp(const ProviderScope(child: DriveTApp()));
}

class DriveTApp extends ConsumerWidget {
  const DriveTApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Drive Tutor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: AppRoutes.router,
    );
  }
}
