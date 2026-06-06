import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import 'app_primary_button.dart';

class MyLessonsEmptyState extends StatelessWidget {
  const MyLessonsEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.xxxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school_rounded,
              size: 96,
              color: AppColors.primary.withValues(alpha: 0.18),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                height: 1.45,
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: actionLabel,
              onPressed: onAction,
            ),
          ],
        ),
      ),
    );
  }
}
