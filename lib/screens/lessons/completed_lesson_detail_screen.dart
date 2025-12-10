import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../models/lesson_model.dart';

class CompletedLessonDetailScreen extends StatelessWidget {
  final LessonModel lesson;

  const CompletedLessonDetailScreen({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE, MMMM d, y').format(lesson.scheduledDate);
    final time = '${lesson.startTime} – ${lesson.endTime}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson Summary'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HeaderCard(lesson: lesson, dateLabel: date, timeLabel: time),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Lesson details',
            children: [
              _DetailRow(icon: Icons.calendar_today, label: date),
              _DetailRow(icon: Icons.schedule, label: '$time (${lesson.duration} hrs)'),
              _DetailRow(icon: Icons.location_on, label: lesson.location ?? 'Location not specified'),
              _DetailRow(icon: Icons.attach_money, label: '\$${lesson.cost.toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 20),
          if (lesson.notes != null && lesson.notes!.isNotEmpty)
            _SectionCard(
              title: 'Instructor notes',
              children: [
                Text(
                  lesson.notes!,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Next steps',
            children: const [
              Text(
                'Keep practising the focus areas your instructor suggested. Book your next session to stay on track.',
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final LessonModel lesson;
  final String dateLabel;
  final String timeLabel;

  const _HeaderCard({
    required this.lesson,
    required this.dateLabel,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final instructor = lesson.instructor;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  '${instructor.user.firstName[0]}${instructor.user.lastName[0]}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${instructor.user.firstName} ${instructor.user.lastName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, color: AppColors.golden, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          instructor.rating.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${instructor.totalLessons} lessons',
                          style: TextStyle(color: Colors.white.withOpacity(0.9)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            dateLabel,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            timeLabel,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.ocean,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _DetailRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

