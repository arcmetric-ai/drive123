import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../services/launch_preferences.dart';

class IntroFlowScreen extends StatefulWidget {
  const IntroFlowScreen({super.key});

  @override
  State<IntroFlowScreen> createState() => _IntroFlowScreenState();
}

class _IntroFlowScreenState extends State<IntroFlowScreen> {
  final PageController _pageController = PageController();
  final List<_IntroPageData> _pages = const [
    _IntroPageData(
      title: 'Schedule lessons with certified instructors',
      subtitle:
          'Stay on track by booking verified instructors and managing lessons from one place.',
      imageAsset: 'assets/images/schedule.svg',
    ),
    _IntroPageData(
      title: 'Discover lessons',
      subtitle:
          'Browse lesson types, compare instructors, and book what best fits your goals.',
      imageAsset: 'assets/images/lesson.svg',
    ),
    _IntroPageData(
      title: 'Welcome to Drive T',
      subtitle:
          'Get started and follow an end-to-end journey that builds confidence behind the wheel.',
      imageAsset: 'assets/images/cart.svg',
    ),
  ];

  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeIntro() async {
    await LaunchPreferences.markIntroSeen();
    if (!mounted) return;
    context.go(AppRoutes.roleSelection);
  }

  void _handleNext() {
    if (_currentPage == _pages.length - 1) {
      _completeIntro();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  void _handlePrevious() {
    if (_currentPage == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  Widget _buildIndicatorDot(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.ocean
            : AppColors.ocean.withOpacity(isActive ? 1 : 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _pages.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return _IntroSlide(
                      title: page.title,
                      subtitle: page.subtitle,
                      imageAsset: page.imageAsset,
                      isActive: index == _currentPage,
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => _buildIndicatorDot(index == _currentPage),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _NavCircleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    background: Colors.white,
                    iconColor: AppColors.ocean,
                    onPressed: _currentPage == 0 ? null : _handlePrevious,
                  ),
                  const Spacer(),
                  _NavCircleButton(
                    icon: Icons.arrow_forward_ios_rounded,
                    background: AppColors.ocean,
                    iconColor: Colors.white,
                    onPressed: _handleNext,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroSlide extends StatelessWidget {
  const _IntroSlide({
    required this.title,
    required this.subtitle,
    required this.imageAsset,
    required this.isActive,
  });

  final String title;
  final String subtitle;
  final String imageAsset;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final double artSize = (screenWidth * 0.9).clamp(340.0, 520.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 32),
        Expanded(
          child: Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              opacity: isActive ? 1 : 0.35,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutBack,
                scale: isActive ? 1 : 0.85,
                child: SizedBox(
                  height: artSize,
                  width: artSize,
                  child: ClipOval(
                    child: Container(
                      color: AppColors.dreamy.withOpacity(0.08),
                      padding: const EdgeInsets.all(12),
                      child: SvgPicture.asset(
                        imageAsset,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavCircleButton extends StatelessWidget {
  const _NavCircleButton({
    required this.icon,
    required this.background,
    required this.iconColor,
    required this.onPressed,
  });

  final IconData icon;
  final Color background;
  final Color iconColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return GestureDetector(
      onTap: disabled ? null : onPressed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: disabled ? 0.3 : 1,
        child: Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _IntroPageData {
  const _IntroPageData({
    required this.title,
    required this.subtitle,
    required this.imageAsset,
  });

  final String title;
  final String subtitle;
  final String imageAsset;
}
