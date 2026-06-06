import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radii.dart';
import '../constants/app_shadows.dart';

class AuthBackButton extends StatelessWidget {
  const AuthBackButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.55),
        shape: BoxShape.circle,
        boxShadow: AppShadows.subtle,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.foreground,
          size: 24,
        ),
        style: IconButton.styleFrom(
          fixedSize: const Size(78, 78),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
        ),
      ),
    );
  }
}
