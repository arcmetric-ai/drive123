import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

class InstructorLearnerDetailScreen extends StatelessWidget {
  final Map<String, dynamic>? learner;

  const InstructorLearnerDetailScreen({super.key, this.learner});

  Map<String, dynamic> get _data => learner ?? const {
        'name': 'Alice Lee',
        'email': 'alice.lee@example.com',
        'phone': '+1 647-555-1200',
        'level': 'G2 practice',
        'progress': '3 / 6 sessions completed',
        'upcoming': 'Next lesson: Oct 14 • 2:00 PM',
        'notes':
            'Working on improving confidence with lane changes. Responds well to checklists and visual cues.',
        'focusAreas': ['Lane changes', 'Downtown traffic', 'Parking'],
        'recentLessons': [
          {
            'date': 'Oct 7, 2024',
            'summary': 'Practised parallel parking and 3-point turns.',
            'feedback': 'Needs smoother steering input when reversing. Improved mirror usage.',
          },
          {
            'date': 'Sep 30, 2024',
            'summary': 'City driving – rush hour intersections.',
            'feedback': 'Better observation before left turns. Continue monitoring speed control.',
          },
        ],
        'testPrep': {
          'targetDate': 'Nov 18, 2024',
          'testCentre': 'Etobicoke DriveTest',
          'readiness': 'On track',
        },
      };

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final focusAreas = (data['focusAreas'] as List).cast<String>();
    final recentLessons = (data['recentLessons'] as List).cast<Map<String, String>>();
    final testPrep = (data['testPrep'] as Map<String, String>);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learner profile'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.message_outlined),
            onPressed: () {
              // TODO: message learner
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _LearnerHeader(name: data['name'] as String, level: data['level'] as String),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Contact details',
            children: [
              _InfoLine(icon: Icons.email_outlined, text: data['email'] as String),
              _InfoLine(icon: Icons.phone_outlined, text: data['phone'] as String),
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Lesson progress',
            children: [
              Text(
                data['progress'] as String,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                data['upcoming'] as String,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: focusAreas
                    .map(
                      (item) => Chip(
                        label: Text(item),
                        backgroundColor: AppColors.primaryBlue.withOpacity(0.12),
                        labelStyle: const TextStyle(color: AppColors.primaryBlue),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Recent lessons',
            children: recentLessons
                .map(
                  (lesson) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RecentLessonTile(lesson: lesson),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Test preparation',
            children: [
              _InfoLine(icon: Icons.calendar_month_outlined, text: 'Target date: ${testPrep['targetDate']}'),
              _InfoLine(icon: Icons.location_on_outlined, text: 'Test centre: ${testPrep['testCentre']}'),
              _InfoLine(icon: Icons.check_circle_outline, text: 'Readiness: ${testPrep['readiness']}'),
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Instructor notes',
            children: [
              Text(
                data['notes'] as String,
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: add progress note
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Add progress note'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LearnerHeader extends StatelessWidget {
  final String name;
  final String level;

  const _LearnerHeader({required this.name, required this.level});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Text(
              name[0],
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 26,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  level,
                  style: TextStyle(color: Colors.white.withOpacity(0.85)),
                ),
              ],
            ),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
          ...children,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentLessonTile extends StatelessWidget {
  final Map<String, String> lesson;

  const _RecentLessonTile({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lesson['date']!,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(lesson['summary']!),
          const SizedBox(height: 6),
          Text(
            lesson['feedback']!,
            style: const TextStyle(color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
