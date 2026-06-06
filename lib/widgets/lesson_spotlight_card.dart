import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import '../constants/app_radii.dart';
import '../constants/app_shadows.dart';
import '../models/lesson_model.dart';

class LessonSpotlightCard extends StatelessWidget {
  const LessonSpotlightCard({
    super.key,
    required this.lesson,
    required this.onDetails,
    this.onCall,
    this.note,
  });

  final LessonModel lesson;
  final VoidCallback onDetails;
  final VoidCallback? onCall;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final instructor = lesson.instructor;
    final user = instructor.user;
    final name = '${user.firstName} ${user.lastName}'.trim().isEmpty
        ? user.email
        : '${user.firstName} ${user.lastName}'.trim();
    final initials = _initials(user.firstName, user.lastName, user.email);
    final profileImage = user.profileImageUrl?.trim();
    final hasProfileImage = profileImage != null && profileImage.isNotEmpty;
    final dateText = _lessonDate(lesson.scheduledDate);
    final timeText = _lessonTimeRange(lesson);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: AppColors.secondary,
                backgroundImage:
                    hasProfileImage ? NetworkImage(profileImage) : null,
                child: hasProfileImage
                    ? null
                    : Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          user.isVerified || instructor.isVerified
                              ? 'VERIFIED'
                              : 'PROFILE',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Text(
                  'CONFIRMED',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.accentForeground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _InfoCard(
                  icon: Icons.calendar_month_rounded,
                  label: 'DATE',
                  value: dateText,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _InfoCard(
                  icon: Icons.schedule_rounded,
                  label: 'TIME',
                  value: timeText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 62,
                  child: ElevatedButton(
                    onPressed: onDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.primaryForeground,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                    child: const Text(
                      'Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              InkWell(
                onTap: onCall,
                borderRadius: BorderRadius.circular(28),
                child: Ink(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    Icons.call_rounded,
                    color: onCall == null
                        ? AppColors.mutedForeground
                        : AppColors.foreground,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
          if (note != null && note!.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_rounded,
                  color: AppColors.accent,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    note!,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _initials(String first, String last, String email) {
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    if (first.isNotEmpty) return first[0].toUpperCase();
    if (email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }

  String _lessonDate(DateTime date) {
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final normalized = DateTime(date.year, date.month, date.day);
    if (normalized == DateTime(today.year, today.month, today.day)) {
      return 'Today, ${DateFormat('MMM d').format(date)}';
    }
    if (normalized == tomorrow) {
      return 'Tomorrow, ${DateFormat('MMM d').format(date)}';
    }
    return DateFormat('EEE, MMM d').format(date);
  }

  String _lessonTimeRange(LessonModel lesson) {
    DateTime? combine(String raw) {
      final formats = [
        DateFormat('h:mm a'),
        DateFormat('hh:mm a'),
        DateFormat('HH:mm'),
        DateFormat('H:mm'),
        DateFormat('HH:mm:ss'),
      ];
      for (final format in formats) {
        try {
          final parsed = format.parse(raw.trim());
          return DateTime(
            lesson.scheduledDate.year,
            lesson.scheduledDate.month,
            lesson.scheduledDate.day,
            parsed.hour,
            parsed.minute,
          );
        } catch (_) {}
      }
      return null;
    }

    final start = combine(lesson.startTime);
    final end = combine(lesson.endTime);
    if (start != null && end != null) {
      return '${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}';
    }
    return '${lesson.startTime} - ${lesson.endTime}';
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.mutedForeground),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.3,
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}
