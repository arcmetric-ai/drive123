import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radii.dart';

class OtpBoxRow extends StatelessWidget {
  const OtpBoxRow({
    super.key,
    required this.code,
    this.length = 6,
  });

  final String code;
  final int length;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const maxBoxWidth = 96.0;
        const minBoxWidth = 48.0;
        final spacing = length >= 6 ? 10.0 : 14.0;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : (maxBoxWidth * length) + (spacing * (length - 1));
        final boxWidth =
            ((availableWidth - (spacing * (length - 1))) / length).clamp(
          minBoxWidth,
          maxBoxWidth,
        );
        final boxHeight = (boxWidth * 1.15).clamp(56.0, 110.0);
        final fontSize = (boxWidth * 0.46).clamp(24.0, 44.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(length, (index) {
            final hasValue = index < code.length;
            final isActive = index == code.length.clamp(0, length - 1);
            return Padding(
              padding:
                  EdgeInsets.only(right: index == length - 1 ? 0 : spacing),
              child: Container(
                width: boxWidth,
                height: boxHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(
                    color: hasValue || isActive
                        ? AppColors.primary
                        : AppColors.border,
                    width: hasValue || isActive ? 2.5 : 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  hasValue ? code[index] : '',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                    height: 1,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
