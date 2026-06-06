import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radii.dart';
import '../constants/app_shadows.dart';
import '../constants/app_spacing.dart';

class PrimaryScheduleLessonCard extends StatelessWidget {
  const PrimaryScheduleLessonCard({
    super.key,
    required this.avatarUrl,
    required this.fallbackInitials,
    required this.instructorName,
    required this.subtitle,
    required this.timeLabel,
    required this.locationLabel,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.onCallPressed,
    this.focusLabel,
  });

  final String? avatarUrl;
  final String fallbackInitials;
  final String instructorName;
  final String subtitle;
  final String timeLabel;
  final String locationLabel;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;
  final VoidCallback? onCallPressed;
  final String? focusLabel;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
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
                    color: AppColors.primary.withValues(alpha: 0.12),
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
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _LessonDetailRow(
            icon: Icons.schedule_outlined,
            label: 'TIME SLOT',
            value: timeLabel,
          ),
          const SizedBox(height: AppSpacing.lg),
          _LessonDetailRow(
            icon: Icons.location_on_outlined,
            label: 'PICKUP LOCATION',
            value: locationLabel,
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 72,
                  child: OutlinedButton(
                    onPressed: onPrimaryPressed,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    child: Text(primaryLabel),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              SizedBox(
                width: 96,
                height: 72,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: IconButton(
                    onPressed: onCallPressed,
                    icon: Icon(
                      Icons.call_rounded,
                      size: 30,
                      color: onCallPressed == null
                          ? AppColors.grey400
                          : AppColors.foreground,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LessonDetailRow extends StatelessWidget {
  const _LessonDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
