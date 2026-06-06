import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radii.dart';
import '../constants/app_shadows.dart';

class DiscoveryFilterChip extends StatelessWidget {
  const DiscoveryFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
            boxShadow: selected ? AppShadows.subtle : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color:
                  selected ? AppColors.primaryForeground : AppColors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}
