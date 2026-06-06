import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../constants/app_colors.dart';
import '../../services/supabase_service.dart';
import '../../widgets/progress_journey_timeline.dart';
import 'progress_chart_screen.dart';

class ProgressTrackerScreen extends StatefulWidget {
  const ProgressTrackerScreen({super.key});

  @override
  State<ProgressTrackerScreen> createState() => _ProgressTrackerScreenState();
}

class _ProgressTrackerScreenState extends State<ProgressTrackerScreen> {
  late List<DrivingSkill> _skills;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _skills = _buildDefaultSkills();
    _loadProgress();
  }

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
            onPressed: _showProgressAnalytics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    color: AppColors.ocean,
                  ),
                ),
                Text(
                  '$completed/$total',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ocean,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.ocean),
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
            if (completed < total) ...[
              const Text(
                'Next Skill to Master:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _skills.firstWhere((skill) => !skill.isCompleted).name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ocean,
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.celebration, color: AppColors.success),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Congratulations! You’ve completed all skills! 🎉',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsCard() {
    final hasCompletedAny = _skills.any((skill) => skill.isCompleted);
    final parkingComplete = _isSkillCompleted('parking');
    final cityComplete = _isSkillCompleted('city_driving');
    final highwayComplete = _isSkillCompleted('highway_driving');

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
                color: AppColors.ocean,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildAchievement(
                  icon: Icons.school,
                  title: 'First Lesson',
                  description: 'Completed your first driving lesson',
                  isUnlocked: hasCompletedAny,
                ),
                const SizedBox(width: 16),
                _buildAchievement(
                  icon: Icons.local_parking,
                  title: 'Parking Pro',
                  description: 'Mastered parallel parking',
                  isUnlocked: parkingComplete,
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
                  isUnlocked: cityComplete,
                ),
                const SizedBox(width: 16),
                _buildAchievement(
                  icon: Icons.speed,
                  title: 'Highway Hero',
                  description: 'Master highway driving',
                  isUnlocked: highwayComplete,
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
              ? AppColors.success.withValues(alpha: 0.1)
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
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isUnlocked ? AppColors.success : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: isUnlocked ? Colors.grey[700] : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsList() {
    final currentIndex = _skills.indexWhere((skill) => !skill.isCompleted);
    final journeySteps = _skills.asMap().entries.map((entry) {
      final index = entry.key;
      final skill = entry.value;

      final state = skill.isCompleted
          ? ProgressJourneyStepState.completed
          : currentIndex == -1
              ? ProgressJourneyStepState.locked
              : index == currentIndex
                  ? ProgressJourneyStepState.current
                  : ProgressJourneyStepState.locked;

      final subtitle = switch (state) {
        ProgressJourneyStepState.completed => skill.completedDate != null
            ? 'Completed ${_formatDate(skill.completedDate!)}'
            : 'Completed',
        ProgressJourneyStepState.current => '',
        ProgressJourneyStepState.locked => skill.description,
      };

      return ProgressJourneyStepData(
        title: skill.name,
        subtitle: subtitle,
        icon: skill.icon,
        state: state,
        onTap: state == ProgressJourneyStepState.locked
            ? null
            : () => _toggleSkillCompletion(skill),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Driving Journey',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.ocean,
          ),
        ),
        const SizedBox(height: 16),
        ProgressJourneyTimeline(steps: journeySteps),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  bool _isSkillCompleted(String id) {
    return _skills.any((skill) => skill.id == id && skill.isCompleted);
  }

  Future<void> _toggleSkillCompletion(DrivingSkill skill) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isCompleting = !skill.isCompleted;
        final title = isCompleting ? 'Mark Skill Complete' : 'Undo Completion';
        final actionLabel =
            isCompleting ? 'Mark Complete' : 'Set to In Progress';
        final message = isCompleting
            ? 'Are you sure you want to mark "${skill.name}" as complete?'
            : 'Set "${skill.name}" back to in progress?';
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await _persistSkillCompletion(skill, complete: !skill.isCompleted);
  }

  Future<void> _persistSkillCompletion(DrivingSkill skill,
      {required bool complete}) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in again to update progress.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final previousCompleted = skill.isCompleted;
    final previousDate = skill.completedDate;
    final timestamp = complete ? DateTime.now() : null;

    setState(() {
      skill.isCompleted = complete;
      skill.completedDate = timestamp;
    });

    try {
      await SupabaseService.upsertLearnerSkillProgress(
        userId: userId,
        skillId: skill.id,
        isCompleted: complete,
        completedAt: timestamp,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            complete
                ? '${skill.name} marked as complete!'
                : '${skill.name} set back to in progress.',
          ),
          backgroundColor: complete ? AppColors.success : AppColors.info,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        skill.isCompleted = previousCompleted;
        skill.completedDate = previousDate;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save progress: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _loadProgress() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final rows = await SupabaseService.getLearnerSkillProgress(userId);
      if (!mounted) return;

      final progressById = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final skillId = row['skill_id'] as String?;
        if (skillId != null) {
          progressById[skillId] = row;
        }
      }

      setState(() {
        for (final skill in _skills) {
          final data = progressById[skill.id];
          if (data != null) {
            final isCompleted = data['is_completed'] as bool? ?? false;
            final completedAt = data['completed_at'];
            DateTime? parsedDate;
            if (completedAt is String && completedAt.isNotEmpty) {
              parsedDate = DateTime.tryParse(completedAt);
            } else if (completedAt is DateTime) {
              parsedDate = completedAt;
            }
            skill.isCompleted = isCompleted;
            skill.completedDate = parsedDate;
          }
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading progress: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showProgressAnalytics() {
    final milestones = _skills
        .where((skill) => skill.isCompleted && skill.completedDate != null)
        .map(
          (skill) => ProgressMilestone(
            title: skill.name,
            description: skill.description,
            completedAt: skill.completedDate!,
          ),
        )
        .toList();

    if (milestones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete a skill to unlock analytics.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProgressChartScreen(
          milestones: milestones,
          totalSkills: _skills.length,
        ),
      ),
    );
  }
}

class DrivingSkill {
  DrivingSkill({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.isCompleted,
    this.completedDate,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  bool isCompleted;
  DateTime? completedDate;
}

List<DrivingSkill> _buildDefaultSkills() {
  return [
    DrivingSkill(
      id: 'basic_vehicle_control',
      name: 'Basic Vehicle Control',
      description: 'Steering, acceleration, and braking',
      icon: Icons.sync_alt_rounded,
      isCompleted: false,
    ),
    DrivingSkill(
      id: 'parking',
      name: 'Parking',
      description: 'Parallel parking and angle parking',
      icon: Icons.local_parking_rounded,
      isCompleted: false,
    ),
    DrivingSkill(
      id: 'city_driving',
      name: 'City Driving',
      description: 'Traffic lights, signs, and intersections',
      icon: Icons.location_city_rounded,
      isCompleted: false,
    ),
    DrivingSkill(
      id: 'highway_driving',
      name: 'Highway Driving',
      description: 'Merging, lane changes, and speed control',
      icon: Icons.route_rounded,
      isCompleted: false,
    ),
    DrivingSkill(
      id: 'night_driving',
      name: 'Night Driving',
      description: 'Driving in low light conditions',
      icon: Icons.nights_stay_rounded,
      isCompleted: false,
    ),
    DrivingSkill(
      id: 'weather_driving',
      name: 'Weather Driving',
      description: 'Driving in rain, snow, and other conditions',
      icon: Icons.cloud_rounded,
      isCompleted: false,
    ),
    DrivingSkill(
      id: 'emergency_situations',
      name: 'Emergency Situations',
      description: 'Handling unexpected situations',
      icon: Icons.warning_amber_rounded,
      isCompleted: false,
    ),
    DrivingSkill(
      id: 'defensive_driving',
      name: 'Defensive Driving',
      description: 'Advanced safety techniques',
      icon: Icons.shield_outlined,
      isCompleted: false,
    ),
  ];
}
