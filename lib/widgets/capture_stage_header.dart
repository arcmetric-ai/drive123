import 'package:flutter/material.dart';

import '../constants/app_radii.dart';
import '../constants/app_spacing.dart';

class CaptureStageHeader extends StatelessWidget {
  const CaptureStageHeader({
    super.key,
    required this.stepLabel,
    required this.onClose,
    this.onAction,
    this.actionIcon = Icons.camera_alt_rounded,
  });

  final String stepLabel;
  final VoidCallback onClose;
  final VoidCallback? onAction;
  final IconData actionIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CircleActionButton(
          icon: Icons.close_rounded,
          onTap: onClose,
        ),
        Expanded(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                stepLabel.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
        ),
        _CircleActionButton(
          icon: actionIcon,
          onTap: onAction,
          showIcon: onAction != null,
        ),
      ],
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.icon,
    required this.onTap,
    this.showIcon = true,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Center(
            child: showIcon
                ? Icon(icon, color: Colors.white, size: 24)
                : Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
