import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import '../constants/app_shadows.dart';
import '../constants/app_spacing.dart';

class AvailabilitySlotCard extends StatelessWidget {
  const AvailabilitySlotCard({
    super.key,
    required this.slot,
    required this.onDelete,
  });

  final String slot;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final (title, timeText) = _buildDisplay(slot);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFE7EEFF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.access_time_filled_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  timeText,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(
              Icons.delete_rounded,
              color: Color(0xFFEF4444),
              size: 30,
            ),
          ),
        ],
      ),
    );
  }

  (String, String) _buildDisplay(String slot) {
    final parts = slot.split('-');
    if (parts.length != 2) {
      return ('SESSION', slot);
    }

    final start = _parseTime(parts.first);
    final end = _parseTime(parts.last);
    final title = _sessionTitle(start.hour);
    final formatted = '${_formatTime(start)} - ${_formatTime(end)}';
    return (title, formatted);
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 0,
      minute: int.tryParse(parts.last) ?? 0,
    );
  }

  String _formatTime(TimeOfDay time) {
    final date = DateTime(2024, 1, 1, time.hour, time.minute);
    return DateFormat('hh:mm a').format(date);
  }

  String _sessionTitle(int hour) {
    if (hour < 12) return 'MORNING SESSION';
    if (hour < 17) return 'AFTERNOON SESSION';
    return 'EVENING SESSION';
  }
}
