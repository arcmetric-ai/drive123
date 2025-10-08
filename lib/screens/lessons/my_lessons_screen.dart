import 'package:flutter/material.dart';
import '../../models/instructor_model.dart';
import '../../models/user_model.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/lesson_model.dart';

class MyLessonsScreen extends StatefulWidget {
  const MyLessonsScreen({super.key});

  @override
  State<MyLessonsScreen> createState() => _MyLessonsScreenState();
}

class _MyLessonsScreenState extends State<MyLessonsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<LessonModel> _upcomingLessons = [
    // Dummy data
    LessonModel(
      id: '1',
      learnerId: 'learner1',
      instructor: InstructorModel(
        id: '1',
        user: UserModel(
          id: '1',
          email: 'john@example.com',
          firstName: 'John',
          lastName: 'Smith',
          role: 'instructor',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        bio: 'Experienced driving instructor',
        yearsOfExperience: 10,
        hourlyRate: 45.0,
        rating: 4.8,
        totalLessons: 250,
        carTypes: ['sedan'],
        transmissionTypes: ['automatic'],
        latitude: 43.6532,
        longitude: -79.3832,
        address: '123 Main St, Toronto, ON',
        availableDays: ['monday', 'tuesday'],
        startTime: '09:00',
        endTime: '17:00',
        languages: ['english'],
      ),
      scheduledDate: DateTime.now().add(const Duration(days: 1)),
      startTime: '14:00',
      endTime: '16:00',
      duration: 2.0,
      cost: 90.0,
      status: LessonStatus.scheduled,
      location: 'Pick up from home',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    LessonModel(
      id: '2',
      learnerId: 'learner1',
      instructor: InstructorModel(
        id: '2',
        user: UserModel(
          id: '2',
          email: 'sarah@example.com',
          firstName: 'Sarah',
          lastName: 'Johnson',
          role: 'instructor',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        bio: 'Patient and friendly instructor',
        yearsOfExperience: 5,
        hourlyRate: 40.0,
        rating: 4.9,
        totalLessons: 180,
        carTypes: ['sedan'],
        transmissionTypes: ['automatic'],
        latitude: 43.6532,
        longitude: -79.3832,
        address: '456 Queen St, Toronto, ON',
        availableDays: ['monday', 'tuesday'],
        startTime: '09:00',
        endTime: '17:00',
        languages: ['english'],
      ),
      scheduledDate: DateTime.now().add(const Duration(days: 3)),
      startTime: '10:00',
      endTime: '11:00',
      duration: 1.0,
      cost: 40.0,
      status: LessonStatus.scheduled,
      location: 'Driving school parking lot',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  final List<LessonModel> _completedLessons = [
    LessonModel(
      id: '3',
      learnerId: 'learner1',
      instructor: InstructorModel(
        id: '1',
        user: UserModel(
          id: '1',
          email: 'john@example.com',
          firstName: 'John',
          lastName: 'Smith',
          role: 'instructor',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        bio: 'Experienced driving instructor',
        yearsOfExperience: 10,
        hourlyRate: 45.0,
        rating: 4.8,
        totalLessons: 250,
        carTypes: ['sedan'],
        transmissionTypes: ['automatic'],
        latitude: 43.6532,
        longitude: -79.3832,
        address: '123 Main St, Toronto, ON',
        availableDays: ['monday', 'tuesday'],
        startTime: '09:00',
        endTime: '17:00',
        languages: ['english'],
      ),
      scheduledDate: DateTime.now().subtract(const Duration(days: 2)),
      startTime: '15:00',
      endTime: '17:00',
      duration: 2.0,
      cost: 90.0,
      status: LessonStatus.completed,
      location: 'Pick up from home',
      notes: 'Great lesson! Focused on parallel parking.',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Lessons'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
          ],
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppColors.primaryBlue,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUpcomingLessons(),
          _buildCompletedLessons(),
        ],
      ),
    );
  }

  Widget _buildUpcomingLessons() {
    if (_upcomingLessons.isEmpty) {
      return _buildEmptyState(
        icon: Icons.schedule_outlined,
        title: 'No Upcoming Lessons',
        subtitle: 'Book your first lesson to get started!',
        actionText: 'Find Instructor',
        onAction: () => context.go('/find-instructor'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _upcomingLessons.length,
      itemBuilder: (context, index) {
        final lesson = _upcomingLessons[index];
        return _buildLessonCard(lesson, isUpcoming: true);
      },
    );
  }

  Widget _buildCompletedLessons() {
    if (_completedLessons.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        title: 'No Completed Lessons',
        subtitle: 'Your completed lessons will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _completedLessons.length,
      itemBuilder: (context, index) {
        final lesson = _completedLessons[index];
        return _buildLessonCard(lesson, isUpcoming: false);
      },
    );
  }

  Widget _buildLessonCard(LessonModel lesson, {required bool isUpcoming}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                  child: Text(
                    '${lesson.instructor.user.firstName[0]}${lesson.instructor.user.lastName[0]}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${lesson.instructor.user.firstName} ${lesson.instructor.user.lastName}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: AppColors.accentYellow,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text('${lesson.instructor.rating}'),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUpcoming
                        ? AppColors.primaryBlue.withOpacity(0.1)
                        : AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isUpcoming ? 'Upcoming' : 'Completed',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isUpcoming
                          ? AppColors.primaryBlue
                          : AppColors.success,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Lesson Details
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, MMMM d, y').format(lesson.scheduledDate),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  '${lesson.startTime} - ${lesson.endTime} (${lesson.duration} hours)',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lesson.location ?? 'Location TBD',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  Icons.attach_money,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  '\$${lesson.cost.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),

            if (lesson.notes != null) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: ${lesson.notes}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            if (isUpcoming) ...[
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showRescheduleDialog(lesson),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Reschedule'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showCancelDialog(lesson),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _startLesson(lesson),
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
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(actionText),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRescheduleDialog(LessonModel lesson) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reschedule Lesson'),
        content: const Text(
            'This feature will be available soon. Please contact your instructor directly.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(LessonModel lesson) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Lesson'),
        content: const Text('Are you sure you want to cancel this lesson?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement cancel lesson
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Lesson cancelled successfully'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _startLesson(LessonModel lesson) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Lesson'),
        content: const Text('Your lesson is starting! Good luck!'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement lesson tracking
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}
