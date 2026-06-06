import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radii.dart';
import '../constants/app_shadows.dart';
import '../constants/app_spacing.dart';

class CompactScheduleLessonCard extends StatelessWidget {
  const CompactScheduleLessonCard({
    super.key,
    required this.avatarUrl,
    required this.fallbackInitials,
    required this.instructorName,
    required this.subtitle,
    required this.dateTimeLabel,
    this.focusLabel,
    this.actionLabel,
    this.onActionPressed,
    this.isMuted = false,
  });

  final String? avatarUrl;
  final String fallbackInitials;
  final String instructorName;
  final String subtitle;
  final String dateTimeLabel;
  final String? focusLabel;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.trim().isNotEmpty;
    final titleColor =
        isMuted ? AppColors.mutedForeground : AppColors.foreground;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.secondary,
                backgroundImage: hasAvatar ? NetworkImage(avatarUrl!) : null,
                child: hasAvatar
                    ? null
                    : Text(
                        fallbackInitials,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      instructorName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedForeground,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (focusLabel != null && focusLabel!.isNotEmpty)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 10,
                    ),
                    child: Text(
                      focusLabel!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              const Icon(
                Icons.schedule_outlined,
                color: AppColors.mutedForeground,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  dateTimeLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              if (actionLabel != null && actionLabel!.isNotEmpty)
                TextButton(
                  onPressed: onActionPressed,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  child: Text(actionLabel!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
