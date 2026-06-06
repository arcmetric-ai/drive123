import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radii.dart';
import '../constants/app_spacing.dart';

class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspacePressed,
  });

  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspacePressed;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows) ...[
          Row(
            children: [
              for (final digit in row)
                Expanded(
                  child: _KeypadButton(
                    onPressed: () => onDigitPressed(digit),
                    child: Text(
                      digit,
                      style: const TextStyle(
                        color: AppColors.primaryForeground,
                        fontSize: 34,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        Row(
          children: [
            const Expanded(child: SizedBox()),
            Expanded(
              child: _KeypadButton(
                onPressed: () => onDigitPressed('0'),
                child: const Text(
                  '0',
                  style: TextStyle(
                    color: AppColors.primaryForeground,
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Align(
                child: SizedBox(
                  width: 52,
                  height: 40,
                  child: Material(
                    color: AppColors.primaryForeground,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      onTap: onBackspacePressed,
                      child: const Center(
                        child: Icon(
                          Icons.close_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    required this.onPressed,
    required this.child,
  });

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryForeground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
        ),
        child: child,
      ),
    );
  }
}
