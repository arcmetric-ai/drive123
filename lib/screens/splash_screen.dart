import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_colors.dart';
import '../constants/app_durations.dart';
import '../constants/app_routes.dart';
import '../constants/app_spacing.dart';
import '../services/launch_preferences.dart';
import '../services/supabase_service.dart';
import '../widgets/app_loading_indicator.dart';
import '../widgets/brand_badge.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _postAnimationHold = Duration(milliseconds: 1800);
  static const _navigationFallbackDelay = Duration(seconds: 4);
  static const _preferenceTimeout = Duration(seconds: 2);
  static const _routeResolutionTimeout = Duration(seconds: 10);

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;
  late final Animation<double> _logoBounce;
  Timer? _fallbackTimer;
  bool _navigationStarted = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this, duration: AppDurations.slow);

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _scale = Tween<double>(
      begin: 0.92,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _logoBounce = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.96,
          end: 1.04,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.04,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
    ]).animate(_controller);

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onAnimationComplete();
      }
    });
    _controller.forward();
    _fallbackTimer =
        Timer(_navigationFallbackDelay, _handlePostSplashNavigation);
  }

  Future<void> _onAnimationComplete() async {
    await Future<void>.delayed(_postAnimationHold);
    if (!mounted) return;
    await _handlePostSplashNavigation();
  }

  Future<void> _handlePostSplashNavigation() async {
    if (_navigationStarted) return;
    _navigationStarted = true;
    _fallbackTimer?.cancel();

    try {
      final shouldShowIntro = await LaunchPreferences.shouldShowIntro().timeout(
        _preferenceTimeout,
        onTimeout: () => false,
      );
      if (!mounted) return;

      if (shouldShowIntro) {
        context.go(AppRoutes.intro);
        return;
      }

      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        context.go(AppRoutes.accountEntry);
        return;
      }
      final user = session.user;

      final destination = await SupabaseService.resolvePostAuthRoute(
        userId: user.id,
        metadataRole: user.userMetadata?['role'],
      ).timeout(_routeResolutionTimeout);

      if (!mounted) return;
      context.go(destination);
    } catch (error) {
      debugPrint('Splash navigation failed: $error');
      if (!mounted) return;
      context.go(AppRoutes.accountEntry);
    }
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.background),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Stack(
              children: [
                Center(
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: ScaleTransition(
                        scale: _scale,
                        child: ScaleTransition(
                          scale: _logoBounce,
                          child: const BrandBadge(size: 280, contentScale: 1),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: AppSpacing.xxxl,
                  child: FadeTransition(
                    opacity: _fade,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'DRIVE TUTOR',
                            style: TextStyle(
                              color: AppColors.foreground,
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.8,
                              height: 1,
                            ),
                          ),
                        ),
                        SizedBox(height: AppSpacing.xxl),
                        _SplashFooter(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashFooter extends StatelessWidget {
  const _SplashFooter();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLoadingIndicator(
          size: 40,
          color: AppColors.brandPrimary,
          trackColor: Color(0x1F054ADA),
        ),
        SizedBox(height: AppSpacing.lg),
        Text(
          'LOADING JOURNEY...',
          style: TextStyle(
            color: AppColors.mutedForeground,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 3.2,
            height: 1,
          ),
        ),
      ],
    );
  }
}
