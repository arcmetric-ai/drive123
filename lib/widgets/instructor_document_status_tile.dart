import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class InstructorDocumentStatusTile extends StatelessWidget {
  const InstructorDocumentStatusTile({
    super.key,
    required this.title,
    required this.statusLabel,
    required this.statusColor,
    required this.icon,
    required this.onTap,
    this.showTrailingArrow = true,
    this.isComplete = false,
  });

  final String title;
  final String statusLabel;
  final Color statusColor;
  final IconData icon;
  final VoidCallback? onTap;
  final bool showTrailingArrow;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A111827),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, color: statusColor, size: 34),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.3,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (isComplete)
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              )
            else if (showTrailingArrow)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedForeground,
                size: 36,
              ),
          ],
        ),
      ),
    );
  }
}
