import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
      title: 'Your availability. Instructor books. You drive.',
      subtitle:
          'Share when you are available, then receive confirmed lesson details from verified instructors.',
      imageAsset: 'assets/images/onboarding_availability.jpg',
      imageAspectRatio: 0.68,
    ),
    _IntroPageData(
      title: 'Book driving lessons that fit your schedule',
      subtitle:
          'Choose your preferences, get schedule updates, and stay ready with reminders.',
      imageAsset: 'assets/images/onboarding_schedule.jpg',
      imageAspectRatio: 0.68,
    ),
    _IntroPageData(
      title: 'Track skills. Build confidence.',
      subtitle:
          'See what is ready, what needs work, and stay test-ready with every lesson.',
      imageAsset: 'assets/images/onboarding_progress.jpg',
      imageAspectRatio: 0.68,
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
    context.go(AppRoutes.accountEntry);
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
            : AppColors.ocean.withValues(alpha: isActive ? 1 : 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      imageAspectRatio: page.imageAspectRatio,
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
                    semanticLabel: 'Previous',
                    background: Colors.white,
                    iconColor: AppColors.ocean,
                    onPressed: _currentPage == 0 ? null : _handlePrevious,
                  ),
                  const Spacer(),
                  _NavCircleButton(
                    icon: Icons.arrow_forward_ios_rounded,
                    semanticLabel: 'Next',
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
    required this.imageAspectRatio,
    required this.isActive,
  });

  final String title;
  final String subtitle;
  final String? imageAsset;
  final double imageAspectRatio;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title. $subtitle',
      image: true,
      child: Center(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          opacity: isActive ? 1 : 0.35,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutBack,
            scale: isActive ? 1 : 0.9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: AspectRatio(
                aspectRatio: imageAspectRatio,
                child: Image.asset(
                  imageAsset!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavCircleButton extends StatelessWidget {
  const _NavCircleButton({
    required this.icon,
    required this.semanticLabel,
    required this.background,
    required this.iconColor,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final Color background;
  final Color iconColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Semantics(
      button: true,
      enabled: !disabled,
      label: semanticLabel,
      onTap: disabled ? null : onPressed,
      child: GestureDetector(
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
                  color: Colors.black.withValues(alpha: 0.08),
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
      ),
    );
  }
}

class _IntroPageData {
  const _IntroPageData({
    required this.title,
    required this.subtitle,
    this.imageAsset,
    this.imageAspectRatio = 9 / 16,
  });

  final String title;
  final String subtitle;
  final String? imageAsset;
  final double imageAspectRatio;
}
