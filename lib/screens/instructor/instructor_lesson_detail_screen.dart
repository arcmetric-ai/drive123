import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';

class InstructorLessonDetailScreen extends StatelessWidget {
  final Map<String, dynamic>? lesson;

  const InstructorLessonDetailScreen({super.key, this.lesson});

  Map<String, dynamic> get _lessonData => lesson ?? const {
        'learner': 'Alice Lee',
        'time': 'Mon, Oct 14 • 09:30 - 11:00',
        'focus': 'G2 practice - downtown intersections',
        'location': 'Union Station, Front St',
        'pickup': 'Learner provided vehicle',
        'notes': 'Work on left turns at busy junctions. Review mirror checks.',
        'status': 'Scheduled',
      };

  @override
  Widget build(BuildContext context) {
    final data = _lessonData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson details'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Lesson editing coming soon.')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HeaderCard(data: data),
          const SizedBox(height: 20),
          _InfoSection(
            title: 'Session info',
            data: data,
            rows: const [
              _InfoRow(label: 'Focus area', valueKey: 'focus'),
              _InfoRow(label: 'Meeting location', valueKey: 'location'),
              _InfoRow(label: 'Vehicle', valueKey: 'pickup'),
            ],
          ),
          const SizedBox(height: 20),
          _InfoSection(
            title: 'Notes for the lesson',
            data: data,
            contentKey: 'notes',
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reschedule flow coming soon.')),
                    );
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: const Text('Reschedule'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lesson started (placeholder).')),
                    );
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start lesson'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              GoRouter.of(context).push(AppRoutes.instructorLearnerDetail, extra: {
                'name': data['learner'],
                'email': 'learner@example.com',
                'phone': '+1 647-555-0000',
                'level': data['focus'],
                'progress': 'Upcoming lesson on ${data['time']}',
                'upcoming': data['time'],
                'notes': data['notes'],
                'focusAreas': [data['focus']],
                'recentLessons': const [],
                'testPrep': const {
                  'targetDate': 'TBD',
                  'testCentre': 'TBD',
                  'readiness': 'Needs assessment',
                },
              });
            },
            icon: const Icon(Icons.person_outline),
            label: const Text('View learner profile'),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _HeaderCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(
                  (data['learner'] as String)[0],
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
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
                      data['learner'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      data['time'] as String,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  data['status'] as String,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<_InfoRow>? rows;
  final String? contentKey;
  final Map<String, dynamic> data;

  const _InfoSection({
    required this.title,
    this.rows,
    this.contentKey,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 12),
          if (rows != null)
            ...rows!.map((row) => row.build(data)),
          if (contentKey != null)
            Text(
              data[contentKey] as String? ?? '',
              style: const TextStyle(height: 1.5),
            ),
        ],
      ),
    );
  }

}

class _InfoRow {
  final String label;
  final String valueKey;

  const _InfoRow({required this.label, required this.valueKey});

  Widget build(Map<String, dynamic> data) {
    final value = data[valueKey] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
