import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_shadows.dart';

class LearnerActionTile extends StatelessWidget {
  const LearnerActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.accentColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final tileAccent = accentColor ?? AppColors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          height: 112,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isPrimary ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isPrimary ? AppColors.primary : AppColors.border,
            ),
            boxShadow: AppShadows.subtle,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isPrimary
                      ? Colors.white.withValues(alpha: 0.14)
                      : tileAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isPrimary ? Colors.white : tileAccent,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  color: isPrimary ? Colors.white : AppColors.foreground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                  color: isPrimary
                      ? Colors.white.withValues(alpha: 0.78)
                      : AppColors.mutedForeground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
