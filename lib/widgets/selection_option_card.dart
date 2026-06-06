import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radii.dart';
import '../constants/app_shadows.dart';
import '../constants/app_spacing.dart';

class SelectionOptionCard extends StatelessWidget {
  const SelectionOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.illustration,
    required this.isSelected,
    required this.onTap,
    this.illustrationBackgroundColor,
    this.selectionColor = AppColors.accent,
    this.isEnabled = true,
    this.illustrationSize = 104,
    this.cardPadding = const EdgeInsets.all(16),
    this.titleFontSize = 22,
    this.subtitleFontSize = 16,
    this.titleTopPadding = 8,
  });

  final String title;
  final String subtitle;
  final Widget illustration;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? illustrationBackgroundColor;
  final Color selectionColor;
  final bool isEnabled;
  final double illustrationSize;
  final EdgeInsetsGeometry cardPadding;
  final double titleFontSize;
  final double subtitleFontSize;
  final double titleTopPadding;

  @override
  Widget build(BuildContext context) {
    final cardBorderColor = isSelected ? selectionColor : AppColors.border;
    final titleColor = isEnabled
        ? AppColors.foreground
        : AppColors.foreground.withValues(alpha: 0.58);
    final subtitleColor = isEnabled
        ? AppColors.mutedForeground
        : AppColors.mutedForeground.withValues(alpha: 0.7);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: isEnabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: cardPadding,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: cardBorderColor,
              width: isSelected ? 2.4 : 1.2,
            ),
            boxShadow: AppShadows.subtle,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: illustrationSize,
                height: illustrationSize,
                decoration: BoxDecoration(
                  color: illustrationBackgroundColor ?? AppColors.secondary,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                padding: const EdgeInsets.all(10),
                child: illustration,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: titleTopPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          height: 1.15,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: subtitleFontSize,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 36,
                height: 36,
                child: isSelected
                    ? const DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: AppColors.accentForeground,
                          size: 20,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
