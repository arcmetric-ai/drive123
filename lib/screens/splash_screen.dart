import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _roadController;
  late AnimationController _letterController;
  late AnimationController _textController;
  
  late Animation<double> _roadAnimation;
  late Animation<double> _letterAnimation;
  late Animation<double> _textAnimation;

  @override
  void initState() {
    super.initState();
    
    _roadController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _letterController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _textController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _roadAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _roadController,
      curve: Curves.easeInOut,
    ));

    _letterAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _letterController,
      curve: Curves.elasticOut,
    ));

    _textAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    ));

    _startAnimation();
  }

  void _startAnimation() async {
    await _roadController.forward();
    await _letterController.forward();
    await _textController.forward();
    
    // Wait a bit then navigate
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (mounted) {
      context.go('/role-selection');
    }
  }

  @override
  void dispose() {
    _roadController.dispose();
    _letterController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Road Line
            AnimatedBuilder(
              animation: _roadAnimation,
              builder: (context, child) {
                return Container(
                  width: 200 * _roadAnimation.value,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.accentYellow,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 40),
            
            // Animated Letter T
            AnimatedBuilder(
              animation: _letterAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _letterAnimation.value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.accentYellow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'T',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 20),
            
            // Animated Drive Text
            AnimatedBuilder(
              animation: _textAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _textAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - _textAnimation.value)),
                    child: const Text(
                      'Drive',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 8),
            
            // Subtitle
            AnimatedBuilder(
              animation: _textAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _textAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - _textAnimation.value)),
                    child: const Text(
                      'Learn. Drive. Thrive.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
