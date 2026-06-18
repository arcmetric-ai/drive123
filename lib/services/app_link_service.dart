// ignore_for_file: cancel_subscriptions

import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_routes.dart';

class AppLinkService {
  AppLinkService._();

  static final AppLinks _appLinks = AppLinks();
  static StreamSubscription<Uri>? _subscription;
  static String? _lastHandledInviteCode;

  static Future<void> initialize() async {
    if (kIsWeb || _subscription != null) return;

    _subscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object error) {
        debugPrint('Unable to handle app link: $error');
      },
    );
  }

  static void _handleUri(Uri uri, [int attempt = 0]) {
    final code = _extractInstructorCode(uri);
    if (code == null) return;

    if (_lastHandledInviteCode == code && attempt == 0) return;
    _lastHandledInviteCode = code;

    final context = AppRoutes.navigatorKey.currentContext;
    if (context == null) {
      if (attempt >= 8) return;
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        _handleUri(uri, attempt + 1);
      });
      return;
    }

    context.go('/invite/instructor/${Uri.encodeComponent(code)}');
  }

  static String? _extractInstructorCode(Uri uri) {
    final isDriveTutorHost =
        uri.host == 'drivetutor.ca' || uri.host == 'www.drivetutor.ca';
    if (!isDriveTutorHost) return null;

    final segments = uri.pathSegments;
    if (segments.length != 3 ||
        segments[0] != 'invite' ||
        segments[1] != 'instructor') {
      return null;
    }

    final code = Uri.decodeComponent(segments[2]).trim().toUpperCase();
    if (code.isEmpty) return null;
    return code;
  }
}
