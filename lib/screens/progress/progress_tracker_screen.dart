import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../constants/app_colors.dart';

class ProgressTrackerScreen extends StatefulWidget {
  const ProgressTrackerScreen({super.key});

  @override
  State<ProgressTrackerScreen> createState() => _ProgressTrackerScreenState();
}

class _ProgressTrackerScreenState extends State<ProgressTrackerScreen> {
  final List<DrivingSkill> _skills = [
    DrivingSkill(
      id: '1',
      name: 'Basic Vehicle Control',
      description: 'Steering, acceleration, and braking',
      isCompleted: true,
      completedDate: DateTime.now().subtract(const Duration(days: 30)),
    ),
    DrivingSkill(
      id: '2',
      name: 'Parking',
      description: 'Parallel parking and angle parking',
      isCompleted: true,
      completedDate: DateTime.now().subtract(const Duration(days: 25)),
    ),
    DrivingSkill(
      id: '3',
      name: 'City Driving',
      description: 'Traffic lights, signs, and intersections',
      isCompleted: true,
      completedDate: DateTime.now().subtract(const Duration(days: 20)),
    ),
    DrivingSkill(
      id: '4',
      name: 'Highway Driving',
      description: 'Merging, lane changes, and speed control',
      isCompleted: false,
    ),
    DrivingSkill(
      id: '5',
      name: 'Night Driving',
      description: 'Driving in low light conditions',
      isCompleted: false,
    ),
    DrivingSkill(
      id: '6',
      name: 'Weather Driving',
      description: 'Driving in rain, snow, and other conditions',
      isCompleted: false,
    ),
    DrivingSkill(
      id: '7',
      name: 'Emergency Situations',
      description: 'Handling unexpected situations',
      isCompleted: false,
    ),
    DrivingSkill(
      id: '8',
      name: 'Defensive Driving',
      description: 'Advanced safety techniques',
      isCompleted: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final completedSkills = _skills.where((skill) => skill.isCompleted).length;
    final totalSkills = _skills.length;
    final progressPercentage = completedSkills / totalSkills;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => _showProgressAnalytics(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress Overview Card
            AnimationLimiter(
              child: Column(
                children: AnimationConfiguration.toStaggeredList(
                  duration: const Duration(milliseconds: 600),
                  childAnimationBuilder: (widget) => SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(child: widget),
                  ),
                  children: [
                    _buildProgressOverviewCard(
                        progressPercentage, completedSkills, totalSkills),
                    const SizedBox(height: 24),
                    _buildAchievementsCard(),
                    const SizedBox(height: 24),
                    _buildSkillsList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressOverviewCard(double progress, int completed, int total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Overall Progress',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
                Text(
                  '$completed/$total',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Progress Bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
              minHeight: 8,
            ),

            const SizedBox(height: 12),

            Text(
              '${(progress * 100).toInt()}% Complete',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),

            const SizedBox(height: 16),

            // Next Skill
            if (completed < total) ...[
              Text(
                'Next Skill to Master:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _skills.firstWhere((skill) => !skill.isCompleted).name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.celebration,
                      color: AppColors.success,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Congratulations! You\'ve completed all skills!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Achievements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildAchievement(
                  icon: Icons.school,
                  title: 'First Lesson',
                  description: 'Completed your first driving lesson',
                  isUnlocked: true,
                ),
                const SizedBox(width: 16),
                _buildAchievement(
                  icon: Icons.local_parking,
                  title: 'Parking Pro',
                  description: 'Mastered parallel parking',
                  isUnlocked: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildAchievement(
                  icon: Icons.directions_car,
                  title: 'City Driver',
                  description: 'Completed city driving skills',
                  isUnlocked: true,
                ),
                const SizedBox(width: 16),
                _buildAchievement(
                  icon: Icons.speed,
                  title: 'Highway Hero',
                  description: 'Master highway driving',
                  isUnlocked: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievement({
    required IconData icon,
    required String title,
    required String description,
    required bool isUnlocked,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUnlocked
              ? AppColors.success.withOpacity(0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isUnlocked ? AppColors.success : Colors.grey[300]!,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isUnlocked ? AppColors.success : Colors.grey[400],
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isUnlocked ? AppColors.success : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 10,
                color: isUnlocked ? Colors.grey[700] : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Driving Skills',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(height: 16),
        ..._skills.asMap().entries.map((entry) {
          final index = entry.key;
          final skill = entry.value;

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 600),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: _buildSkillCard(skill),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSkillCard(DrivingSkill skill) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Status Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: skill.isCompleted
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                skill.isCompleted ? Icons.check : Icons.radio_button_unchecked,
                color: skill.isCompleted
                    ? AppColors.success
                    : AppColors.primaryBlue,
                size: 20,
              ),
            ),

            const SizedBox(width: 16),

            // Skill Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skill.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color:
                          skill.isCompleted ? Colors.grey[700] : Colors.black87,
                      decoration:
                          skill.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    skill.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (skill.isCompleted && skill.completedDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Completed on ${_formatDate(skill.completedDate!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Action Button
            if (!skill.isCompleted)
              ElevatedButton(
                onPressed: () => _markSkillComplete(skill),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  minimumSize: const Size(80, 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Mark Done',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _markSkillComplete(DrivingSkill skill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Skill Complete'),
        content:
            Text('Are you sure you want to mark "${skill.name}" as complete?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                skill.isCompleted = true;
                skill.completedDate = DateTime.now();
              });
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${skill.name} marked as complete!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Mark Complete'),
          ),
        ],
      ),
    );
  }

  void _showProgressAnalytics() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Progress Analytics'),
        content: const Text('Detailed analytics will be available soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class DrivingSkill {
  DrivingSkill({
    required this.id,
    required this.name,
    required this.description,
    required this.isCompleted,
    this.completedDate,
  });
  final String id;
  final String name;
  final String description;
  bool isCompleted;
  DateTime? completedDate;
}
