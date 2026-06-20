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
    this.compact = false,
  });

  final String title;
  final String statusLabel;
  final Color statusColor;
  final IconData icon;
  final VoidCallback? onTap;
  final bool showTrailingArrow;
  final bool isComplete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Ink(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 9 : 16,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
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
              width: compact ? 40 : 52,
              height: compact ? 40 : 52,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: statusColor, size: compact ? 21 : 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: compact ? 15 : 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (isComplete)
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              )
            else if (showTrailingArrow)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedForeground,
                size: 30,
              ),
          ],
        ),
      ),
    );
  }
}
