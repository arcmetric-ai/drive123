import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radii.dart';
import '../constants/app_spacing.dart';

class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({
    super.key,
    required this.password,
  });

  final String password;

  int get _score {
    var score = 0;
    if (password.length >= 8) score += 1;
    if (RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password)) {
      score += 1;
    }
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=/\\[\];`~]').hasMatch(password)) {
      score += 1;
    }
    return score.clamp(0, 3);
  }

  String get _label {
    if (_score >= 3) return 'STRONG PASSWORD';
    if (_score == 2) return 'GOOD PASSWORD';
    if (_score == 1) return 'WEAK PASSWORD';
    return 'ADD A STRONG PASSWORD';
  }

  @override
  Widget build(BuildContext context) {
    final colors = <Color>[
      _score >= 1 ? AppColors.accent : AppColors.secondary,
      _score >= 2 ? AppColors.primary : AppColors.secondary,
      _score >= 3 ? AppColors.primary : AppColors.secondary,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < colors.length; i++) ...[
              Expanded(
                child: Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[i],
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                ),
              ),
              if (i < colors.length - 1) const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          _label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
