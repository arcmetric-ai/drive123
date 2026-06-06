import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radii.dart';
import '../constants/app_shadows.dart';

class AppCircleIconButton extends StatelessWidget {
  const AppCircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 48,
    this.backgroundColor,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.card,
        shape: BoxShape.circle,
        boxShadow: AppShadows.subtle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: iconColor ?? AppColors.foreground,
          size: size * 0.46,
        ),
        style: IconButton.styleFrom(
          fixedSize: Size(size, size),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        ),
      ),
    );
  }
}
