import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
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

  Future<void> _handleComplete() async {
    if (widget.onMarkCompleted == null || _isCompleting) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isCompleting = true);

    LessonModel? updated;
    try {
      updated = await widget.onMarkCompleted!();
    } finally {
      if (mounted) {
        setState(() => _isCompleting = false);
      }
    }

    if (!mounted) return;

    if (updated == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Something went wrong. Please try marking the lesson again.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('EEEE, MMMM d, y');
    final timeFormatter = DateFormat.jm();
    String startTimeDisplay;
    try {
      startTimeDisplay =
          timeFormatter.format(DateFormat('HH:mm').parse(lesson.startTime));
    } catch (_) {
      startTimeDisplay = lesson.startTime;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ongoing Lesson'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInstructorHeader(),
              const SizedBox(height: 24),
              _buildInfoTile(
                icon: Icons.calendar_today,
                title: 'Today’s Session',
                value: dateFormatter.format(lesson.scheduledDate),
              ),
              const SizedBox(height: 12),
              _buildInfoTile(
                icon: Icons.schedule,
                title: 'Time Window',
                value:
                    '${lesson.startTime} - ${lesson.endTime} (${lesson.duration} hrs)',
              ),
              const SizedBox(height: 12),
              _buildInfoTile(
                icon: Icons.access_time_filled,
                title: 'Started At',
                value: startTimeDisplay,
              ),
              if (lesson.location != null) ...[
                const SizedBox(height: 12),
                _buildInfoTile(
                  icon: Icons.location_on,
                  title: 'Meeting Point',
                  value: lesson.location!,
                ),
              ],
              if (lesson.notes != null && lesson.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildInfoTile(
                  icon: Icons.sticky_note_2_outlined,
                  title: 'Session Notes',
                  value: lesson.notes!,
                ),
              ],
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                color: AppColors.ocean.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.ocean,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Focus on your driving – we’re keeping track of this session in the background.',
                          style: TextStyle(
                            color: AppColors.ocean.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: _isCompleting ? null : _handleComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ocean,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
                        : const Text(
                            'Mark Lesson Complete',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isCompleting
                        ? null
                        : () => Navigator.pop(context, null),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructorHeader() {
    final instructor = lesson.instructor.user;
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.ocean.withOpacity(0.15),
          child: Text(
            '${instructor.firstName[0]}${instructor.lastName[0]}',
            style: const TextStyle(
              color: AppColors.ocean,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${instructor.firstName} ${instructor.lastName}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Session cost \$${lesson.cost.toStringAsFixed(0)}',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppColors.ocean,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ocean,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
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

