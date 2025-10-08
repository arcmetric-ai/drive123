import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../services/supabase_service.dart';
import '../instructor/find_instructor_screen.dart';
import '../lessons/my_lessons_screen.dart';
import '../progress/progress_tracker_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialFocus, this.initialLocation});

  final String? initialFocus;
  final String? initialLocation;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String? _selectedFocus;
  String? _selectedLocation;
  String? _profileFirstName;
  int _completedSkills = 0;
  bool _isProgressLoading = false;
  String? _nextSkillName;

  static const int _totalSkills = 8;
  static const List<String> _skillOrder = [
    'basic_vehicle_control',
    'parking',
    'city_driving',
    'highway_driving',
    'night_driving',
    'weather_driving',
    'emergency_situations',
    'defensive_driving',
  ];
  static const Map<String, String> _skillNameLookup = {
    'basic_vehicle_control': 'Basic Vehicle Control',
    'parking': 'Parking',
    'city_driving': 'City Driving',
    'highway_driving': 'Highway Driving',
    'night_driving': 'Night Driving',
    'weather_driving': 'Weather Driving',
    'emergency_situations': 'Emergency Situations',
    'defensive_driving': 'Defensive Driving',
  };

  @override
  void initState() {
    super.initState();
    _selectedFocus = widget.initialFocus;
    _selectedLocation = widget.initialLocation;
    _loadProfileSummary();
    _loadProgressSummary();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFocus != oldWidget.initialFocus) {
      _selectedFocus = widget.initialFocus;
    }
    if (widget.initialLocation != oldWidget.initialLocation) {
      _selectedLocation = widget.initialLocation;
    }
    if (_selectedIndex == 0) {
      _loadProfileSummary();
      _loadProgressSummary();
    }
  }

  String get _greetingName {
    if (_profileFirstName != null && _profileFirstName!.isNotEmpty) {
      return _profileFirstName!;
    }
    final user = SupabaseService.currentUser;
    final metadata = user?.userMetadata ?? {};
    final firstName = metadata['first_name'] as String?;
    if (firstName != null && firstName.isNotEmpty) {
      return firstName;
    }
    final email = user?.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'there';
  }

  String get _userRole {
    final role = SupabaseService.currentUser?.userMetadata?['role'] as String?;
    return role ?? 'learner';
  }

  bool get _isLearner => _userRole != 'instructor';

  Future<void> _handleSelectLocation() async {
    final result = await GoRouter.of(context).push<String>(AppRoutes.locationSetup);
    if (result != null && result.isNotEmpty) {
      setState(() => _selectedLocation = result);
    }
  }

  Future<void> _handleChangeFocus() async {
    if (!_isLearner) {
      return;
    }
    GoRouter.of(context).push(AppRoutes.learningFocus, extra: 'learner');
  }

  void _openTab(int index) {
    setState(() => _selectedIndex = index);
    if (index == 0) {
      _loadProfileSummary();
      _loadProgressSummary();
    }
  }

  void _goToProfile() => _openTab(4);
  void _goToProgress() => _openTab(3);
  void _goToLessons() => _openTab(2);
  void _goToFindInstructor() => _openTab(1);

  Future<void> _loadProfileSummary() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      return;
    }

    try {
      final profile = await SupabaseService.getUserProfile(userId);
      final learnerDetail = await SupabaseService.getLearnerProfileDetail(userId);
      if (!mounted) return;
      setState(() {
        if (profile != null) {
          _profileFirstName = profile.firstName;
        }
        final focus = learnerDetail?['learning_focus'] as String?;
        if (focus != null && focus.isNotEmpty) {
          _selectedFocus = focus;
        }
      });
    } catch (_) {
      // ignore silently
    }
  }

  Future<void> _loadProgressSummary() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      return;
    }

    setState(() => _isProgressLoading = true);

    try {
      final rows = await SupabaseService.getLearnerSkillProgress(userId);
      if (!mounted) return;

      final completed = rows.where((row) => row['is_completed'] == true).length;
      final completedIds = rows
          .where((row) => row['is_completed'] == true)
          .map((row) => row['skill_id'] as String?)
          .whereType<String>()
          .toSet();

      String? nextSkill;
      for (final id in _skillOrder) {
        if (!completedIds.contains(id)) {
          nextSkill = _skillNameLookup[id];
          break;
        }
      }

      setState(() {
        _completedSkills = completed;
        _nextSkillName = nextSkill;
        _isProgressLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isProgressLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_selectedIndex) {
      0 => HomeDashboard(
          name: _greetingName,
          isLearner: _isLearner,
          locationLabel: _selectedLocation,
          selectedFocus: _selectedFocus,
          completedSkills: _completedSkills,
          totalSkills: _totalSkills,
          nextSkillName: _nextSkillName,
          isProgressLoading: _isProgressLoading,
          onAddLocation: _handleSelectLocation,
          onChangeFocus: _handleChangeFocus,
          onBookLesson: _goToFindInstructor,
          onMyLessons: _goToLessons,
          onProgress: _goToProgress,
          onProfile: _goToProfile,
        ),
      1 => FindInstructorScreen(selectedFocus: _selectedFocus),
      2 => const MyLessonsScreen(),
      3 => const ProgressTrackerScreen(),
      4 => const ProfileScreen(),
      _ => const SizedBox.shrink(),
    };

    return Scaffold(
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 1 && _selectedFocus == null && _isLearner) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Select a training focus to see tailored instructors.'),
                backgroundColor: AppColors.info,
              ),
            );
            _handleChangeFocus();
            return;
          }
          _openTab(index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryBlue,
        unselectedItemColor: Colors.grey[500],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined),
            activeIcon: Icon(Icons.search),
            label: 'Find',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule_outlined),
            activeIcon: Icon(Icons.schedule),
            label: 'Lessons',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.track_changes_outlined),
            activeIcon: Icon(Icons.track_changes),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeDashboard extends StatelessWidget {
  final String name;
  final bool isLearner;
  final String? locationLabel;
  final String? selectedFocus;
  final int completedSkills;
  final int totalSkills;
  final String? nextSkillName;
  final bool isProgressLoading;
  final VoidCallback onAddLocation;
  final VoidCallback onChangeFocus;
  final VoidCallback onBookLesson;
  final VoidCallback onMyLessons;
  final VoidCallback onProgress;
  final VoidCallback onProfile;

  const HomeDashboard({
    super.key,
    required this.name,
    required this.isLearner,
    required this.locationLabel,
    required this.selectedFocus,
    required this.completedSkills,
    required this.totalSkills,
    required this.nextSkillName,
    required this.isProgressLoading,
    required this.onAddLocation,
    required this.onChangeFocus,
    required this.onBookLesson,
    required this.onMyLessons,
    required this.onProgress,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drive T'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Implement notifications
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: AnimationLimiter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 500),
              childAnimationBuilder: (widget) => SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(child: widget),
              ),
              children: [
                _buildGreetingCard(),
                const SizedBox(height: 20),
                if (isLearner) _buildFocusCard(),
                if (isLearner) const SizedBox(height: 20),
                _buildQuickActions(),
                const SizedBox(height: 24),
                _buildUpcomingLessons(),
                const SizedBox(height: 24),
                _buildProgressOverview(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingCard() {
    final hasLocation = locationLabel != null && locationLabel!.isNotEmpty;

    return Container(
      width: double.infinity,
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
          Text(
            'Hey $name 👋',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Let’s get you road-ready today.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  hasLocation ? Icons.location_on : Icons.add_location_alt,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hasLocation
                        ? locationLabel!
                        : 'Add your pickup location to discover instructors nearby.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: onAddLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primaryBlue,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(hasLocation ? 'Update' : 'Add'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusCard() {
    final focusLabel = _formatFocus(selectedFocus);
    final hasFocus = selectedFocus != null && selectedFocus!.isNotEmpty;

    return GestureDetector(
      onTap: onChangeFocus,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.accentYellow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.emoji_events,
                color: AppColors.primaryBlue,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    focusLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasFocus
                        ? 'Tap to change your training focus.'
                        : 'Pick G2, G, or Practice to see matching instructors.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18, color: AppColors.primaryBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                title: 'Book Lesson',
                subtitle: 'Find an instructor',
                icon: Icons.add_circle_outline,
                color: AppColors.primaryBlue,
                onTap: onBookLesson,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                title: 'My Lessons',
                subtitle: 'See schedule',
                icon: Icons.schedule_outlined,
                color: AppColors.accentYellow,
                onTap: onMyLessons,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                title: 'Progress',
                subtitle: 'Track milestones',
                icon: Icons.track_changes_outlined,
                color: AppColors.success,
                onTap: onProgress,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                title: 'Profile',
                subtitle: 'Manage account',
                icon: Icons.person_outline,
                color: AppColors.info,
                onTap: onProfile,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpcomingLessons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Upcoming Lessons',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            TextButton(
              onPressed: onMyLessons,
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'John Smith',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tomorrow, 2:00 PM',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '2 hours',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Start lesson
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Start'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressOverview() {
    final clampedTotal = totalSkills <= 0 ? 1 : totalSkills;
    final validCompleted = completedSkills.clamp(0, clampedTotal);
    final progressValue = clampedTotal == 0 ? 0.0 : validCompleted / clampedTotal;
    final completedLabel = '$validCompleted/$clampedTotal';
    final nextLabel = nextSkillName ?? 'All skills completed';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Progress Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Skills Completed',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    completedLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isProgressLoading)
                const LinearProgressIndicator()
              else ...[
                LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Next: $nextLabel',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    TextButton(
                      onPressed: onProgress,
                      child: const Text('View Details'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatFocus(String? focus) {
    switch (focus) {
      case 'G2':
        return 'G2 Road Test';
      case 'G':
        return 'G Road Test';
      case 'PR':
        return 'Practice Sessions';
      default:
        return 'Choose training focus';
    }
  }
}

class _QuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
