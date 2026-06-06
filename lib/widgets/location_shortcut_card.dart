import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radii.dart';
import '../constants/app_spacing.dart';

class LocationShortcutCard extends StatelessWidget {
  const LocationShortcutCard({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 122,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5F8FF) : AppColors.card,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.6 : 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppColors.primary : AppColors.mutedForeground,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? AppColors.foreground
                    : AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
