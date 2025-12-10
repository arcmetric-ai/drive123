import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_colors.dart';
import '../constants/app_routes.dart';
import '../services/launch_preferences.dart';
import '../services/supabase_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _iconScale;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleOffset;
  late final Animation<double> _subtitleOpacity;
  late final Animation<Offset> _subtitleOffset;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    _iconScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
    );
    _iconOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.75, curve: Curves.easeOut),
    );
    _titleOffset = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.75, curve: Curves.easeOut),
      ),
    );

    _subtitleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
    );
    _subtitleOffset = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller
      ..forward()
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _onAnimationComplete();
        }
      });
  }

  Future<void> _onAnimationComplete() async {
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    await _handlePostSplashNavigation();
  }

  Future<void> _handlePostSplashNavigation() async {
    try {
      final shouldShowIntro = await LaunchPreferences.shouldShowIntro();
      if (!mounted) return;

      if (shouldShowIntro) {
        context.go(AppRoutes.intro);
        return;
      }

      final session = Supabase.instance.client.auth.currentSession;
      if (session == null || session.user == null) {
        context.go(AppRoutes.roleSelection);
        return;
      }

      var role = session.user!.userMetadata?['role'] as String?;
      if (role == null) {
        final profile =
            await SupabaseService.getRawProfile(session.user!.id);
        role = profile?['role'] as String?;
      }

      if (!mounted) return;
      if (role == 'instructor') {
        context.go(AppRoutes.instructorHome);
      } else {
        context.go(AppRoutes.home);
      }
    } catch (error) {
      debugPrint('Splash navigation failed: $error');
      if (!mounted) return;
      context.go(AppRoutes.roleSelection);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double logoWidth =
        ((screenWidth * 0.48).clamp(160.0, 300.0)) as double;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/Car_2.png',
            fit: BoxFit.cover,
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  final logoTop = constraints.maxHeight * 0.10;
                  final textTop = constraints.maxHeight * 0.74;

                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: logoTop,
                        child: Transform.translate(
                          offset: const Offset(0, -12),
                          child: ScaleTransition(
                            scale: _iconScale,
                            child: FadeTransition(
                              opacity: _iconOpacity,
                              child: SvgPicture.asset(
                                'assets/images/drive_t_logo_only.svg',
                                width: logoWidth,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: textTop,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FadeTransition(
                              opacity: _titleOpacity,
                              child: SlideTransition(
                                position: _titleOffset,
                                child: const Text(
                                  'DRIVE - T',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'BungeeInline',
                                    fontSize: 54,
                                    letterSpacing: 1.1,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black45,
                                        offset: Offset(0, 2),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                              ),
                            ),
                          ),
                            const SizedBox(height: 16),
                            FadeTransition(
                              opacity: _subtitleOpacity,
                              child: SlideTransition(
                                position: _subtitleOffset,
                                child: const Text(
                                  'Learn. Drive. Thrive',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'MartianMono',
                                    fontSize: 22,
                                    letterSpacing: 0.6,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xF2FFFFFF),
                                    shadows: [
                                      Shadow(
                                        color: Colors.black45,
                                        offset: Offset(0, 2),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
