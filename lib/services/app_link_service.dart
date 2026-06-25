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
  static String? _lastHandledAuthLink;

  static Future<void> initialize() async {
    if (kIsWeb || _subscription != null) return;

    _subscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object error) {
        debugPrint('Unable to handle app link: $error');
      },
    );

    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleUri(initialLink);
      }
    } catch (error) {
      debugPrint('Unable to read initial app link: $error');
    }
  }

  static void _handleUri(Uri uri, [int attempt = 0]) {
    final authLocation = _extractAuthRedirectLocation(uri);
    if (authLocation != null) {
      if (_lastHandledAuthLink == uri.toString() && attempt == 0) return;
      _lastHandledAuthLink = uri.toString();
      _routeWhenReady(authLocation, uri, attempt);
      return;
    }

    final code = _extractInstructorCode(uri);
    if (code == null) return;

    if (_lastHandledInviteCode == code && attempt == 0) return;
    _lastHandledInviteCode = code;

    _routeWhenReady(
        '/invite/instructor/${Uri.encodeComponent(code)}', uri, attempt);
  }

  static void _routeWhenReady(String location, Uri uri, int attempt) {
    final context = AppRoutes.navigatorKey.currentContext;
    if (context == null) {
      if (attempt >= 8) return;
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        _handleUri(uri, attempt + 1);
      });
      return;
    }

    context.go(location);
  }

  static String? _extractInstructorCode(Uri uri) {
    final isDriveTutorHost =
        uri.host == 'drivetutor.ca' || uri.host == 'www.drivetutor.ca';
    final isCustomInviteLink =
        uri.scheme == 'drivetutor' && uri.host == 'invite';
    if (!isDriveTutorHost && !isCustomInviteLink) return null;

    final segments = uri.pathSegments;
    final codeSegment = isCustomInviteLink
        ? (segments.length == 2 && segments[0] == 'instructor'
            ? segments[1]
            : null)
        : (segments.length == 3 &&
                segments[0] == 'invite' &&
                segments[1] == 'instructor'
            ? segments[2]
            : null);
    if (codeSegment == null) {
      return null;
    }

    final code = Uri.decodeComponent(codeSegment).trim().toUpperCase();
    if (code.isEmpty) return null;
    return code;
  }

  static String? _extractAuthRedirectLocation(Uri uri) {
    final isDriveTutorHost =
        uri.host == 'drivetutor.ca' || uri.host == 'www.drivetutor.ca';
    final isWebAuthRedirect = isDriveTutorHost &&
        uri.pathSegments.length == 1 &&
        uri.pathSegments.first == 'auth-redirect';
    final isCustomAuthRedirect =
        uri.scheme == 'drivetutor' && uri.host == 'auth-redirect';
    if (!isWebAuthRedirect && !isCustomAuthRedirect) return null;

    final query = uri.hasQuery ? '?${uri.query}' : '';
    return '${AppRoutes.authRedirect}$query';
  }
}
