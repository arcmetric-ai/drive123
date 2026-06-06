import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

class OnboardingStepBars extends StatelessWidget {
  const OnboardingStepBars({
    super.key,
    required this.activeStep,
    this.totalSteps = 4,
  });

  final int activeStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index < activeStep;
        return Container(
          width: 64,
          height: 8,
          margin: EdgeInsets.only(
            right: index == totalSteps - 1 ? 0 : AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.secondary,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
