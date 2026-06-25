import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_radii.dart';
import '../../constants/app_spacing.dart';
import '../../models/lesson_model.dart';

class OngoingLessonScreen extends StatefulWidget {
  const OngoingLessonScreen({
    super.key,
    required this.lesson,
    this.onMarkCompleted,
  });

  final LessonModel lesson;
  final Future<LessonModel?> Function()? onMarkCompleted;

  @override
  State<OngoingLessonScreen> createState() => _OngoingLessonScreenState();
}

class _OngoingLessonScreenState extends State<OngoingLessonScreen> {
  bool _isCompleting = false;

  LessonModel get lesson => widget.lesson;

  Future<void> _handlePrimaryAction() async {
    if (widget.onMarkCompleted == null) {
      Navigator.pop(context, null);
      return;
    }
    if (_isCompleting) return;

    setState(() => _isCompleting = true);
    LessonModel? updated;
    try {
      updated = await widget.onMarkCompleted!();
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }

    if (!mounted) return;
    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to mark the lesson complete. Try again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat('EEEE, MMMM d, y').format(lesson.scheduledDate.toLocal());
    final timeLabel =
        '${_formatClockLabel(lesson.startTime)} - ${_formatClockLabel(lesson.endTime)}';
    final durationMinutes = (lesson.duration * 60).round();
    final focusLabel = _focusLabel();
    final notes = lesson.notes?.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lesson Details'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 22),
                  _InfoTile(
                    icon: Icons.calendar_month_rounded,
                    label: 'Date',
                    value: dateLabel,
                  ),
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.schedule_rounded,
                    label: 'Time',
                    value: '$timeLabel ($durationMinutes mins)',
                  ),
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.track_changes_rounded,
                    label: 'Training focus',
                    value: focusLabel,
                  ),
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.location_on_rounded,
                    label: 'Pickup location',
                    value: lesson.location ?? 'Location to be confirmed',
                  ),
                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _InfoTile(
                      icon: Icons.sticky_note_2_rounded,
                      label: 'Instructor notes',
                      value: notes,
                    ),
                  ],
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your instructor manages lesson changes. Contact them directly if the lesson is within 72 hours.',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isCompleting ? null : _handlePrimaryAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryForeground,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  child: _isCompleting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.onMarkCompleted == null
                              ? 'Close'
                              : 'Mark Lesson Complete',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final instructor = lesson.instructor.user;
    final name = '${instructor.firstName} ${instructor.lastName}'.trim();
    final image = instructor.profileImageUrl?.trim();
    final hasImage = image != null && image.isNotEmpty;
    final initials = _initials(
      instructor.firstName,
      instructor.lastName,
      instructor.email,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            backgroundImage: hasImage ? NetworkImage(image) : null,
            child: hasImage
                ? null
                : Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? instructor.email : name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  lesson.isInProgress ? 'In progress' : 'Scheduled lesson',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _focusLabel() {
    final focus = lesson.focus?.trim();
    if (focus == null || focus.isEmpty) return 'Training session';
    final normalized = focus.toLowerCase();
    if (normalized.contains('g2')) return 'G2 preparation';
    if (normalized == 'g' || normalized.contains('g prep')) {
      return 'G preparation';
    }
    if (normalized.contains('refresh') || normalized == 'pr') {
      return 'Refresher lesson';
    }
    return focus;
  }

  String _formatClockLabel(String raw) {
    final formats = <DateFormat>[
      DateFormat('h:mm a'),
      DateFormat('hh:mm a'),
      DateFormat('H:mm'),
      DateFormat('HH:mm'),
      DateFormat('HH:mm:ss'),
    ];
    for (final format in formats) {
      try {
        return DateFormat('h:mm a').format(format.parse(raw.trim()));
      } catch (_) {}
    }
    return raw.trim();
  }

  String _initials(String first, String last, String email) {
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    if (first.isNotEmpty) return first[0].toUpperCase();
    if (email.isNotEmpty) return email[0].toUpperCase();
    return 'DT';
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
