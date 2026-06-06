import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radii.dart';
import '../constants/app_shadows.dart';
import '../constants/app_spacing.dart';

class ScheduleDayCard extends StatelessWidget {
  const ScheduleDayCard({
    super.key,
    required this.monthLabel,
    required this.dayLabel,
    required this.weekdayLabel,
    required this.isSelected,
    required this.hasLesson,
    required this.onTap,
  });

  final String monthLabel;
  final String dayLabel;
  final String weekdayLabel;
  final bool isSelected;
  final bool hasLesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground =
        isSelected ? AppColors.primaryForeground : AppColors.foreground;
    final muted = isSelected
        ? AppColors.primaryForeground.withValues(alpha: 0.82)
        : AppColors.mutedForeground;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: isSelected ? 112 : 96,
        height: 152,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          boxShadow: isSelected ? AppShadows.subtle : const [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Text(
                  monthLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                    color: muted,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  dayLabel,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  weekdayLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                    color: muted,
                  ),
                ),
              ],
            ),
            if (hasLesson)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent : AppColors.primary,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
