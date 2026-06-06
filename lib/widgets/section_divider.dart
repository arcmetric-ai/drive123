import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

class SectionDivider extends StatelessWidget {
  const SectionDivider({
    super.key,
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: AppColors.border, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: AppColors.border, thickness: 1),
        ),
      ],
    );
  }
}
