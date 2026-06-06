import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../constants/app_colors.dart';
import '../../models/learner_progress.dart';
import '../../services/supabase_service.dart';
import '../../widgets/progress_journey_timeline.dart';
import 'progress_chart_screen.dart';

class ProgressTrackerScreen extends StatefulWidget {
  const ProgressTrackerScreen({super.key});

  @override
  State<ProgressTrackerScreen> createState() => _ProgressTrackerScreenState();
}

class _ProgressTrackerScreenState extends State<ProgressTrackerScreen> {
  late List<LearnerProgressSkill> _skills;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _skills = defaultLearnerProgressSkills();
    _loadProgress();
  }

  @override
  Widget build(BuildContext context) {
    final testReadySkills =
        _skills.where((skill) => skill.status.isTestReady).length;
    final totalSkills = _skills.length;
    final progressPercentage =
        _skills.fold<double>(0, (sum, skill) => sum + skill.status.score) /
            totalSkills;

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
              child: AnimationLimiter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 600),
                    childAnimationBuilder: (widget) => SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(child: widget),
                    ),
                    children: [
                      _buildProgressOverviewCard(
                        progressPercentage,
                        testReadySkills,
                        totalSkills,
                      ),
                      const SizedBox(height: 24),
                      _buildAchievementsCard(),
                      const SizedBox(height: 24),
                      _buildSkillsList(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildProgressOverviewCard(double progress, int ready, int total) {
    LearnerProgressSkill? nextSkill;
    for (final skill in _skills) {
      if (!skill.status.isTestReady) {
        nextSkill = skill;
        break;
      }
    }

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
                  '$ready/$total ready',
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
              value: progress.clamp(0, 1),
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
            if (nextSkill != null) ...[
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
                nextSkill.name,
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
                        'All skills are test ready.',
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
            const SizedBox(height: 12),
            Text(
              'Your instructor updates this progress after lessons.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsCard() {
    final hasProgress =
        _skills.any((skill) => skill.status != LearnerSkillStatus.notStarted);
    final parkingReady = _isSkillTestReady('parking');
    final cityReady = _isSkillTestReady('city_driving');
    final highwayReady = _isSkillTestReady('highway_driving');

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
                  title: 'Started',
                  description: 'Progress has been reviewed',
                  isUnlocked: hasProgress,
                ),
                const SizedBox(width: 16),
                _buildAchievement(
                  icon: Icons.local_parking,
                  title: 'Parking Ready',
                  description: 'Parking skills are test ready',
                  isUnlocked: parkingReady,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildAchievement(
                  icon: Icons.directions_car,
                  title: 'City Ready',
                  description: 'City driving is test ready',
                  isUnlocked: cityReady,
                ),
                const SizedBox(width: 16),
                _buildAchievement(
                  icon: Icons.speed,
                  title: 'Highway Ready',
                  description: 'Highway driving is test ready',
                  isUnlocked: highwayReady,
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
    final journeySteps = _skills.map((skill) {
      return ProgressJourneyStepData(
        title: skill.name,
        subtitle: _skillSubtitle(skill),
        icon: skill.icon,
        state: _timelineState(skill.status),
        onTap: null,
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

  String _skillSubtitle(LearnerProgressSkill skill) {
    final date = skill.completedAt ?? skill.updatedAt;
    final dateText = date != null ? ' - ${_formatDate(date)}' : '';
    return '${skill.status.label}$dateText';
  }

  ProgressJourneyStepState _timelineState(LearnerSkillStatus status) {
    switch (status) {
      case LearnerSkillStatus.notStarted:
        return ProgressJourneyStepState.locked;
      case LearnerSkillStatus.practicing:
      case LearnerSkillStatus.confident:
        return ProgressJourneyStepState.current;
      case LearnerSkillStatus.testReady:
        return ProgressJourneyStepState.completed;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  bool _isSkillTestReady(String id) {
    return _skills.any((skill) => skill.id == id && skill.status.isTestReady);
  }

  Future<void> _loadProgress() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final rows = await SupabaseService.getLearnerSkillProgress(userId);
      if (!mounted) return;

      setState(() {
        _skills = learnerProgressSkillsFromRows(rows);
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
        .where((skill) => skill.status.isTestReady && skill.completedAt != null)
        .map(
          (skill) => ProgressMilestone(
            title: skill.name,
            description: skill.description,
            completedAt: skill.completedAt!,
          ),
        )
        .toList();

    if (milestones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your test-ready milestones will appear here.'),
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
