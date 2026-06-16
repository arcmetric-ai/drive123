import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _initialized = false;
  static String? _lastRegisteredToken;

  static Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    await _configureForegroundPresentation();

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
    _lastRegisteredToken = token;
  }

  static Future<void> _configureForegroundPresentation() async {
    if (!Platform.isIOS && !Platform.isMacOS) return;

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static String get _platformName {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    if (Platform.isMacOS) return 'macos';
    return 'web';
  }
}
