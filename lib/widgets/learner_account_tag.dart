import 'package:flutter/material.dart';

class LearnerAccountTag extends StatelessWidget {
  const LearnerAccountTag({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
  });

  const LearnerAccountTag.offline({super.key})
      : label = 'Offline',
        backgroundColor = const Color(0xFFFFF4CC),
        foregroundColor = const Color(0xFF7A5600),
        icon = Icons.person_off_outlined;

  const LearnerAccountTag.guardian({super.key})
      : label = 'Guardian',
        backgroundColor = const Color(0xFFEDE9FE),
        foregroundColor = const Color(0xFF5B21B6),
        icon = Icons.supervisor_account_outlined;

  const LearnerAccountTag.graduated({super.key})
      : label = 'Graduated',
        backgroundColor = const Color(0xFFE7F8EF),
        foregroundColor = const Color(0xFF0B7A3B),
        icon = Icons.school_outlined;

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foregroundColor.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foregroundColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foregroundColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
