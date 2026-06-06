import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.size = 36,
    this.color = AppColors.brandPrimaryForeground,
    this.trackColor = const Color(0x33FFFFFF),
    this.strokeWidth = 4,
  });

  final double size;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(color),
        backgroundColor: trackColor,
      ),
    );
  }
}
