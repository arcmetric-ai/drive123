import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_spacing.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/auth_back_button.dart';
import '../../widgets/onboarding_step_bars.dart';

class IdentityVerificationIntroScreen extends StatelessWidget {
  const IdentityVerificationIntroScreen({
    super.key,
    required this.role,
  });

  final String role;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AuthBackButton(onPressed: () => context.pop()),
                  const SizedBox(width: AppSpacing.md),
                  const Expanded(
                    child: Align(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: OnboardingStepBars(activeStep: 1),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 44),
              const Text(
                'Verify Identity',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                  letterSpacing: -0.7,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                "To keep our community safe, we need to verify the account holder's driver's license before lessons can be requested.",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 38),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.foreground.withValues(alpha: 0.04),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: AppColors.border,
                              width: 2,
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.border,
                                width: 3,
                              ),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 72,
                                  color: AppColors.mutedForeground,
                                ),
                                SizedBox(height: AppSpacing.lg),
                                Text(
                                  "ONTARIO DRIVER'S LICENSE",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2.2,
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const _VerificationTip(
                        number: '1',
                        title: 'Good Lighting',
                        description: 'Make sure you are in a well-lit room.',
                      ),
                      const SizedBox(height: 22),
                      const _VerificationTip(
                        number: '2',
                        title: 'No Glare',
                        description:
                            'Avoid direct reflections on the card surface.',
                      ),
                      const SizedBox(height: 22),
                      const _VerificationTip(
                        number: '3',
                        title: 'Full Frame',
                        description:
                            'Ensure all four corners are visible in the photo.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              AppPrimaryButton(
                label: "I'm Ready",
                onPressed: () => context.go(
                  AppRoutes.identityLicenseCapture,
                  extra: {'role': role},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationTip extends StatelessWidget {
  const _VerificationTip({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0xFFE6EEFF),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
