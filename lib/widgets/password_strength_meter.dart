import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radii.dart';
import '../constants/app_spacing.dart';
import '../utils/password_rules.dart';

class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({
    super.key,
    required this.password,
  });

  final String password;

  int get _metCount {
    return [
      PasswordRules.hasMinimumLength(password),
      PasswordRules.hasLowercase(password),
      PasswordRules.hasUppercase(password),
      PasswordRules.hasDigit(password),
      PasswordRules.hasSymbol(password),
    ].where((isMet) => isMet).length;
  }

  bool get _isValid => PasswordRules.isValid(password);

  @override
  Widget build(BuildContext context) {
    final metCount = _metCount;
    final progress = password.isEmpty ? 0.0 : metCount / 5;
    final progressColor = _isValid ? AppColors.success : AppColors.primaryBlue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isValid
              ? AppColors.success.withValues(alpha: 0.28)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.secondary,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '$metCount/5',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _isValid ? AppColors.success : AppColors.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Password must include',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _RequirementRow(
            label: 'At least 8 characters',
            isMet: PasswordRules.hasMinimumLength(password),
          ),
          _RequirementRow(
            label: 'Lowercase letter',
            isMet: PasswordRules.hasLowercase(password),
          ),
          _RequirementRow(
            label: 'Uppercase letter',
            isMet: PasswordRules.hasUppercase(password),
          ),
          _RequirementRow(
            label: 'Number',
            isMet: PasswordRules.hasDigit(password),
          ),
          _RequirementRow(
            label: 'Symbol',
            isMet: PasswordRules.hasSymbol(password),
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    required this.label,
    required this.isMet,
  });

  final String label;
  final bool isMet;

  @override
  Widget build(BuildContext context) {
    final color = isMet ? AppColors.success : AppColors.mutedForeground;
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
