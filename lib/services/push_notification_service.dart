import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_routes.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static const String _androidChannelId = 'drive_tutor_updates';
  static const String _androidChannelName = 'Drive Tutor updates';
  static bool _initialized = false;
  static String? _lastRegisteredToken;

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    await _configureForegroundPresentation();
    await _initializeLocalNotifications();

    Supabase.instance.client.auth.onAuthStateChange.listen((event) async {
      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.tokenRefreshed ||
          event.event == AuthChangeEvent.userUpdated) {
        await registerCurrentDevice();
      }
    });

    _messaging.onTokenRefresh.listen((token) async {
      await _registerToken(token);
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }

    if (Supabase.instance.client.auth.currentUser != null) {
      await registerCurrentDevice();
    }
  }

  static Future<void> registerCurrentDevice() async {
    if (kIsWeb) return;

    final settings = await _messaging.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;

    await _registerToken(token);
  }

  static Future<void> revokeCurrentDevice() async {
    if (kIsWeb) return;

    final token = _lastRegisteredToken ?? await _messaging.getToken();
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null && token != null && token.isNotEmpty) {
      await Supabase.instance.client
          .from('device_tokens')
          .update({
            'is_active': false,
            'revoked_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('profile_id', userId)
          .eq('fcm_token', token);
    }
    _lastRegisteredToken = null;
  }

  static Future<void> _registerToken(String token) async {
    if (Supabase.instance.client.auth.currentUser == null) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await Supabase.instance.client.from('device_tokens').upsert(
      {
        'profile_id': userId,
        'fcm_token': token,
        'platform': _platformName,
        'is_active': true,
        'revoked_at': null,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'fcm_token',
    );
    await _ensureDefaultPreferences(userId);
    _lastRegisteredToken = token;
  }

  static Future<void> _ensureDefaultPreferences(String userId) async {
    final client = Supabase.instance.client;
    final existing = await client
        .from('notification_preferences')
        .select('profile_id')
        .eq('profile_id', userId)
        .maybeSingle();
    if (existing != null) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final payload = {
      'profile_id': userId,
      'fcm_enabled': true,
      'email_enabled': true,
      'lesson_updates_enabled': true,
      'lesson_reminders_enabled': true,
      'review_updates_enabled': true,
      'pass_updates_enabled': true,
      'support_updates_enabled': true,
      'marketing_enabled': false,
      'timezone': 'America/Toronto',
      'created_at': now,
      'updated_at': now,
    };

    try {
      await client.from('notification_preferences').insert(payload);
    } catch (_) {
      final fallback = Map<String, dynamic>.from(payload)
        ..remove('lesson_reminders_enabled');
      try {
        await client.from('notification_preferences').insert(fallback);
      } catch (_) {}
    }
  }

  static Future<void> _configureForegroundPresentation() async {
    if (!Platform.isIOS && !Platform.isMacOS) return;

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> _initializeLocalNotifications() async {
    if (!Platform.isAndroid) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload);
          if (data is Map<String, dynamic>) {
            _navigateFromData(data);
          }
        } catch (_) {}
      },
    );

    const channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: 'Important account, lesson, and verification updates',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (!Platform.isAndroid) return;

    final notification = message.notification;
    final title = notification?.title;
    final body = notification?.body;
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      channelDescription: 'Important account, lesson, and verification updates',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _localNotifications.show(
      id: message.messageId.hashCode,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails),
      payload: jsonEncode(message.data),
    );
  }

  static void _handleMessageOpenedApp(RemoteMessage message) {
    _navigateFromData(message.data);
  }

  static void _navigateFromData(Map<String, dynamic> data, [int attempt = 0]) {
    final screen = data['screen']?.toString();
    final context = AppRoutes.navigatorKey.currentContext;
    if (screen == null) return;
    if (context == null) {
      if (attempt >= 5) return;
      Future<void>.delayed(const Duration(milliseconds: 600), () {
        _navigateFromData(data, attempt + 1);
      });
      return;
    }

    switch (screen) {
      case 'review_learner_request':
      case 'instructor_requests':
        context.go(AppRoutes.instructorHome);
        break;
      case 'instructor_activation':
        context.go(AppRoutes.instructorBilling);
        break;
      case 'instructor_credentials':
      case 'instructor_credentials_request':
        context.go(AppRoutes.instructorCredentialsPortal);
        break;
      case 'verification_status':
      case 'verification_document_request':
      case 'identity_pending_review':
        context.go(AppRoutes.identityPendingReview);
        break;
      case 'my_lessons':
        context.go(AppRoutes.myLessons);
        break;
      case 'find_instructor':
        context.go(AppRoutes.findInstructor);
        break;
      case 'instructor_dashboard':
        context.go(AppRoutes.instructorHome);
        break;
      case 'home':
      default:
        context.go(AppRoutes.home);
        break;
    }
  }

  static String get _platformName {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    return 'web';
  }
}
