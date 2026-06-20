import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'constants/app_theme.dart';
import 'constants/app_routes.dart';
import 'services/app_link_service.dart';
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

  // Initialize Supabase
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const ProviderScope(child: DriveTApp()));

  unawaited(_initializeDeferredServices());
}

Future<void> _initializeDeferredServices() async {
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 8));
    await PushNotificationService.initialize().timeout(
      const Duration(seconds: 8),
    );
  } catch (error, stackTrace) {
    debugPrint('Deferred Firebase/push initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  try {
    await AppLinkService.initialize().timeout(const Duration(seconds: 4));
  } catch (error, stackTrace) {
    debugPrint('Deferred app link initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}

class DriveTApp extends ConsumerStatefulWidget {
  const DriveTApp({super.key});

  @override
  ConsumerState<DriveTApp> createState() => _DriveTAppState();
}

class _DriveTAppState extends ConsumerState<DriveTApp> {
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (state) {
        if (state.event == AuthChangeEvent.signedOut) {
          AppRoutes.router.go(AppRoutes.auth);
        }
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Drive Tutor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: AppRoutes.router,
    );
  }
}
