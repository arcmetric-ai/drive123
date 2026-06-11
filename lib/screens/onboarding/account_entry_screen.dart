import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_spacing.dart';
import '../../widgets/app_outline_button.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/brand_intro_header.dart';

class AccountEntryScreen extends StatelessWidget {
  const AccountEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BrandIntroHeader(
                title: 'Drive Tutor',
                subtitle: 'Manage lessons, requests, and your driving journey.',
                badgeSize: 88,
                badgeBackgroundColor: AppColors.primaryBlue,
                badgeContentScale: 1.4,
              ),
              const Spacer(),
              const _AppSummary(),
              const Spacer(),
              AppPrimaryButton(
                label: 'Create an Account',
                onPressed: () => context.go(AppRoutes.roleSelection),
              ),
              const SizedBox(height: AppSpacing.md),
              AppOutlineButton(
                label: 'I Have an Account',
                onPressed: () => context.go(AppRoutes.auth),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppSummary extends StatelessWidget {
  const _AppSummary();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryItem(
          icon: Icons.verified_user_rounded,
          title: 'Learn with verified instructors',
          description:
              'Find certified driving instructors and request lessons that fit your schedule.',
        ),
        SizedBox(height: AppSpacing.lg),
        _SummaryItem(
          icon: Icons.event_available_rounded,
          title: 'Keep every lesson organized',
          description:
              'Track requests, lesson times, progress updates, and account notifications in one place.',
        ),
        SizedBox(height: AppSpacing.lg),
        _SummaryItem(
          icon: Icons.family_restroom_rounded,
          title: 'Guardian-managed accounts',
          description:
              'Parents and guardians can manage young learner accounts and receive important updates.',
        ),
      ],
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: AppColors.primaryBlue,
            size: 22,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
