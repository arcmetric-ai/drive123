import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

class OtpCodeDisplay extends StatelessWidget {
  const OtpCodeDisplay({
    super.key,
    required this.code,
    this.length = 6,
  });

  final String code;
  final int length;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (index) {
        final hasValue = index < code.length;
        final value = hasValue ? code[index] : '0';
        return Padding(
          padding: EdgeInsets.only(
            right: index == length - 1 ? 0 : AppSpacing.sm,
          ),
          child: SizedBox(
            width: 48,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.primaryForeground.withValues(
                      alpha: hasValue ? 1 : 0.28,
                    ),
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primaryForeground.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
