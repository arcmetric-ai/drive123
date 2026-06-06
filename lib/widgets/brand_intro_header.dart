import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import 'brand_badge.dart';

class BrandIntroHeader extends StatelessWidget {
  const BrandIntroHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.badgeSize = 112,
    this.badgeBackgroundColor,
    this.badgePadding = const EdgeInsets.all(10),
    this.badgeContentScale = 1.8,
  });

  final String title;
  final String subtitle;
  final double badgeSize;
  final Color? badgeBackgroundColor;
  final EdgeInsets badgePadding;
  final double badgeContentScale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BrandBadge(
          size: badgeSize,
          backgroundColor: badgeBackgroundColor,
          padding: badgePadding,
          contentScale: badgeContentScale,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          title,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.16,
            letterSpacing: -0.6,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.45,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}
