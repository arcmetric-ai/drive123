import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../models/lesson_model.dart';
import '../../services/supabase_service.dart';
import 'ongoing_lesson_screen.dart';

class MyLessonsScreen extends StatefulWidget {
  const MyLessonsScreen({super.key});

  @override
  State<MyLessonsScreen> createState() => _MyLessonsScreenState();
}

class _MyLessonsScreenState extends State<MyLessonsScreen>
    with SingleTickerProviderStateMixin {
  static const int _learnerMonthlyCancelLimit = 3;
  late TabController _tabController;

  final List<LessonModel> _upcomingLessons = [];
  final List<LessonModel> _completedLessons = [];
  final List<LessonModel> _cancelledLessons = [];
  LessonModel? _ongoingLesson;
  bool _isProcessingAction = false;
  bool _loading = true;
  String? _error;

  Future<void> _loadLessons({bool showLoader = true}) async {
    final learnerId = SupabaseService.currentUser?.id;
    if (learnerId == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Please sign in to view your lessons.';
        _upcomingLessons.clear();
        _completedLessons.clear();
        _cancelledLessons.clear();
        _ongoingLesson = null;
      });
      return;
    }

    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() {
        _error = null;
      });
    }

    try {
      final lessons = await SupabaseService.getLessons(learnerId);
      final normalizedLessons = lessons
          .map(
            (lesson) => lesson.effectiveStatus == lesson.status
                ? lesson
                : lesson.copyWith(status: lesson.effectiveStatus),
          )
          .toList();

      final upcoming = <LessonModel>[];
      final completed = <LessonModel>[];
      final cancelled = <LessonModel>[];
      LessonModel? ongoing;

      for (final lesson in normalizedLessons) {
        switch (lesson.status) {
          case LessonStatus.scheduled:
            upcoming.add(lesson);
            break;
          case LessonStatus.completed:
            completed.add(lesson);
            break;
          case LessonStatus.cancelled:
            cancelled.add(lesson);
            break;
          case LessonStatus.inProgress:
            ongoing ??= lesson;
            break;
        }
      }

      upcoming.sort(
        (a, b) => a.scheduledDate.compareTo(b.scheduledDate),
      );
      completed.sort(
        (a, b) => b.scheduledDate.compareTo(a.scheduledDate),
      );
      cancelled.sort(
        (a, b) => b.scheduledDate.compareTo(a.scheduledDate),
      );

      if (!mounted) return;
      setState(() {
        _upcomingLessons
          ..clear()
          ..addAll(upcoming);
        _completedLessons
          ..clear()
          ..addAll(completed);
        _cancelledLessons
          ..clear()
          ..addAll(cancelled);
        _ongoingLesson = ongoing;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load lessons right now. Please try again.';
      });
    }
  }

  Future<void> _refreshLessons() => _loadLessons(showLoader: false);

  bool get _hasAnyLessons =>
      _ongoingLesson != null ||
      _upcomingLessons.isNotEmpty ||
      _completedLessons.isNotEmpty ||
      _cancelledLessons.isNotEmpty;

  double _resolveLessonPrice(LessonModel lesson) {
    if (lesson.cost > 0) return lesson.cost;

    final duration = lesson.duration > 0 ? lesson.duration : 1.0;
    final hourlyRate = lesson.instructor.hourlyRate;
    final offeringRates = lesson.instructor.offeringRates.values
        .where((rate) => rate > 0)
        .toList();
    final bestOfferingRate =
        offeringRates.isNotEmpty ? offeringRates.reduce((a, b) => a < b ? a : b) : 0.0;

    final fallbackRate = bestOfferingRate > 0 ? bestOfferingRate : hourlyRate;
    final computed = fallbackRate > 0 ? fallbackRate * duration : 0.0;
    return computed > 0 ? computed : 0.0;
  }

  String _formatPriceLabel(LessonModel lesson) {
    final price = _resolveLessonPrice(lesson);
    if (price <= 0) return 'Price to be confirmed';

    final needsDecimals = price % 1 != 0;
    final formatted = needsDecimals ? price.toStringAsFixed(2) : price.toStringAsFixed(0);
    return '\$$formatted';
  }

  DateTime _lessonStartDateTime(LessonModel lesson) {
    final scheduledDate = lesson.scheduledDate.toLocal();
    final timeLabel = lesson.startTime.trim();
    final parts = timeLabel.split(':');

    int hour = scheduledDate.hour;
    int minute = scheduledDate.minute;

    if (parts.length >= 2) {
      final rawHour = int.tryParse(parts[0]);
      final rawMinute =
          int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), ''));
      final upperLabel = timeLabel.toUpperCase();

      if (rawHour != null) {
        hour = rawHour;
        if (upperLabel.contains('PM') && rawHour < 12) {
          hour = rawHour + 12;
        } else if (upperLabel.contains('AM') && rawHour == 12) {
          hour = 0;
        }
      }
      if (rawMinute != null) {
        minute = rawMinute.clamp(0, 59).toInt();
      }
    }

    return DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      hour,
      minute,
    );
  }

  bool _canCancelLesson(LessonModel lesson) {
    final start = _lessonStartDateTime(lesson);
    final now = DateTime.now();
    if (!start.isAfter(now)) return false;
    return start.difference(now) >= const Duration(hours: 72);
  }

  Future<int?> _remainingLearnerCancels() async {
    final learnerId = SupabaseService.currentUser?.id;
    if (learnerId == null) return null;
    try {
      final used = await SupabaseService.getMonthlyCancellationCount(
        userId: learnerId,
        isInstructor: false,
      );
      final remaining = _learnerMonthlyCancelLimit - used;
      return remaining < 0 ? 0 : remaining;
    } catch (_) {
      return null;
    }
  }

  String _contactInstructorText(LessonModel lesson) {
    final name = lesson.instructor.user.firstName;
    final phone = lesson.instructor.user.phone?.trim();
    final email = lesson.instructor.user.email.trim();
    final contacts = <String>[];
    if (phone != null && phone.isNotEmpty) {
      contacts.add('Phone: $phone');
    }
    if (email.isNotEmpty) {
      contacts.add('Email: $email');
    }
    final contactLabel =
        contacts.isNotEmpty ? ' (${contacts.join(' | ')})' : '';
    return 'This lesson starts soon. Cancellations within 72 hours must be arranged directly with $name$contactLabel.';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLessons();
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
            Tab(text: 'Cancelled'),
          ],
          labelColor: AppColors.ocean,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppColors.ocean,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUpcomingLessons(),
          _buildCompletedLessons(),
          _buildCancelledLessons(),
        ],
      ),
    );
  }

  Widget _buildUpcomingLessons() {
    if (_loading) {
      return _buildLoadingView();
    }
    if (_error != null) {
      return _buildErrorState();
    }
    final hasOngoing = _ongoingLesson != null;
    if (!_hasAnyLessons) {
      return _buildStartLearningView();
    }
    if (_upcomingLessons.isEmpty && !hasOngoing) {
      return _buildEmptyState(
        icon: Icons.schedule_outlined,
        title: 'No Upcoming Lessons',
        subtitle:
            'Your instructor\'s weekly plan will appear here once it\'s shared.',
        actionText: 'Find Instructor',
        onAction: () => context.go(AppRoutes.findInstructor),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshLessons,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_ongoingLesson != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildOngoingLessonBanner(_ongoingLesson!),
            ),
          for (final lesson in _upcomingLessons)
            _buildLessonCard(lesson, statusLabel: LessonStatus.scheduled),
        ],
      ),
    );
  }

  Widget _buildCompletedLessons() {
    if (_loading) {
      return _buildLoadingView();
    }
    if (_error != null) {
      return _buildErrorState();
    }
    if (!_hasAnyLessons) {
      return _buildStartLearningView();
    }
    if (_completedLessons.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        title: 'No Completed Lessons',
        subtitle: 'Your completed lessons will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshLessons,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _completedLessons.length,
        itemBuilder: (context, index) {
          final lesson = _completedLessons[index];
          return _buildLessonCard(lesson, statusLabel: LessonStatus.completed);
        },
      ),
    );
  }

  Widget _buildCancelledLessons() {
    if (_loading) {
      return _buildLoadingView();
    }
    if (_error != null) {
      return _buildErrorState();
    }
    if (!_hasAnyLessons) {
      return _buildStartLearningView();
    }
    if (_cancelledLessons.isEmpty) {
      return _buildEmptyState(
        icon: Icons.cancel_outlined,
        title: 'No Cancelled Lessons',
        subtitle: 'Cancelled lessons will appear here for your records.',
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshLessons,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _cancelledLessons.length,
        itemBuilder: (context, index) {
          final lesson = _cancelledLessons[index];
          return _buildLessonCard(lesson, statusLabel: LessonStatus.cancelled);
        },
      ),
    );
  }

  Widget _buildLessonCard(
    LessonModel lesson, {
    required LessonStatus statusLabel,
  }) {
    final canCancel = _canCancelLesson(lesson);
    final priceValue = _resolveLessonPrice(lesson);
    final profileImageUrl = lesson.instructor.user.profileImageUrl?.trim();
    final hasProfileImage =
        profileImageUrl != null && profileImageUrl.isNotEmpty;

    Color chipColor;
    Color textColor;
    String label;

    switch (statusLabel) {
      case LessonStatus.scheduled:
        chipColor = AppColors.ocean.withOpacity(0.1);
        textColor = AppColors.ocean;
        label = 'Upcoming';
        break;
      case LessonStatus.inProgress:
        chipColor = AppColors.golden.withOpacity(0.15);
        textColor = AppColors.golden;
        label = 'In Progress';
        break;
      case LessonStatus.completed:
        chipColor = AppColors.success.withOpacity(0.12);
        textColor = AppColors.success;
        label = 'Completed';
        break;
      case LessonStatus.cancelled:
        chipColor = AppColors.error.withOpacity(0.12);
        textColor = AppColors.error;
        label = 'Cancelled';
        break;
    }

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
                  backgroundColor: AppColors.ocean.withOpacity(0.1),
                  backgroundImage:
                      hasProfileImage ? NetworkImage(profileImageUrl) : null,
                  child: hasProfileImage
                      ? null
                      : Text(
                          '${lesson.instructor.user.firstName[0]}${lesson.instructor.user.lastName[0]}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ocean,
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
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: chipColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textColor,
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
                  _formatPriceLabel(lesson),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color:
                        priceValue > 0 ? AppColors.ocean : Colors.grey[700],
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

            if (statusLabel == LessonStatus.scheduled) ...[
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessingAction || !canCancel
                          ? null
                          : () => _showCancelDialog(lesson),
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
                      onPressed: _isProcessingAction
                          ? null
                          : () => _startLesson(lesson),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ocean,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Start'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                canCancel
                    ? 'You can cancel up to 72 hours before the lesson start if you need a different time.'
                    : _contactInstructorText(lesson),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
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
    return RefreshIndicator(
      onRefresh: _refreshLessons,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          if (actionText != null && onAction != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ocean,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(actionText),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showCancelDialog(LessonModel lesson) async {
    if (!_canCancelLesson(lesson)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cancellations are only allowed up to 72 hours before your lesson. Please contact your instructor.',
          ),
        ),
      );
      return;
    }

    final remaining = await _remainingLearnerCancels();
    if (remaining != null && remaining <= 0) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel limit reached'),
          content: const Text(
            'You have reached your monthly cancellation limit. Please contact your instructor directly to reschedule or cancel.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Lesson'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to cancel this lesson?'),
            const SizedBox(height: 12),
            if (remaining != null)
              Text(
                'You have $remaining of $_learnerMonthlyCancelLimit cancellations left this month. After you run out, you will need to contact your instructor directly.',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            const SizedBox(height: 8),
            const Text(
              'Cancellations are allowed up to 72 hours before the lesson start.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: _isProcessingAction
                ? null
                : () {
                    Navigator.pop(context);
                    _cancelLesson(lesson);
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

  Future<void> _startLesson(LessonModel lesson) async {
    if (_ongoingLesson != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There is already a live session in progress.'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Lesson'),
        content: Text(
          'Start your session with ${lesson.instructor.user.firstName}? '
          'We’ll open the live session view with all the details you need.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Yet'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirm != true || _isProcessingAction) return;

    setState(() => _isProcessingAction = true);

    LessonModel? updated;
    try {
      updated = await SupabaseService.updateLessonStatus(
        lesson.id,
        LessonStatus.inProgress.name,
      );
    } catch (_) {
      updated = null;
    }

    updated ??= lesson.copyWith(
      status: LessonStatus.inProgress,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _upcomingLessons.removeWhere((l) => l.id == lesson.id);
      _ongoingLesson = updated;
      _isProcessingAction = false;
    });

    if (!mounted) return;

    final result = await Navigator.of(context).push<LessonModel?>(
      MaterialPageRoute(
        builder: (context) => OngoingLessonScreen(
          lesson: updated!,
          onMarkCompleted: () => _completeLesson(updated!),
        ),
      ),
    );

    if (!mounted) return;
    if (result != null) {
      _handleLessonCompletion(result);
    }
  }

  Future<void> _cancelLesson(LessonModel lesson) async {
    if (_isProcessingAction) return;
    if (!_canCancelLesson(lesson)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This lesson can no longer be cancelled in the app. Please reach out to your instructor directly.',
          ),
        ),
      );
      return;
    }
    final remaining = await _remainingLearnerCancels();
    if (remaining != null && remaining <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You have reached your monthly cancellation limit. Please contact your instructor directly.',
          ),
        ),
      );
      return;
    }

    setState(() => _isProcessingAction = true);

    LessonModel? updated;
    try {
      updated = await SupabaseService.updateLessonStatus(
        lesson.id,
        LessonStatus.cancelled.name,
      );
    } catch (_) {
      updated = null;
    }

    updated ??= lesson.copyWith(
      status: LessonStatus.cancelled,
      updatedAt: DateTime.now(),
    );

    setState(() {
      _upcomingLessons.removeWhere((l) => l.id == lesson.id);
      _cancelledLessons.insert(0, updated!);
      if (_ongoingLesson?.id == lesson.id) {
        _ongoingLesson = null;
      }
      _isProcessingAction = false;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Lesson cancelled. You can book another time anytime.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<LessonModel?> _completeLesson(LessonModel lesson) async {
    LessonModel? updated;
    try {
      updated = await SupabaseService.updateLessonStatus(
        lesson.id,
        LessonStatus.completed.name,
      );
    } catch (_) {
      updated = null;
    }

    updated ??= lesson.copyWith(
      status: LessonStatus.completed,
      updatedAt: DateTime.now(),
    );

    setState(() {
      if (_ongoingLesson?.id == lesson.id) {
        _ongoingLesson = null;
      }
      _completedLessons.insert(0, updated!);
    });

    return updated;
  }

  void _handleLessonCompletion(LessonModel lesson) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Great work! Lesson with ${lesson.instructor.user.firstName} wrapped up.',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Widget _buildOngoingLessonBanner(LessonModel lesson) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.golden.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.play_circle_fill,
                color: AppColors.golden,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Lesson in progress with ${lesson.instructor.user.firstName} ${lesson.instructor.user.lastName}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Started at ${lesson.startTime}. Tap below to view live session details.',
            style: TextStyle(
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<LessonModel?>(
                  MaterialPageRoute(
                    builder: (context) => OngoingLessonScreen(
                      lesson: lesson,
                      onMarkCompleted: () => _completeLesson(lesson),
                    ),
                  ),
                );
                if (!mounted) return;
                if (result != null) {
                  _handleLessonCompletion(result);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ocean,
              ),
              child: const Text('Open Session'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorState() {
    return RefreshIndicator(
      onRefresh: _refreshLessons,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          Icon(
            Icons.wifi_off_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unable to load your lessons right now.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _refreshLessons,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ocean,
              ),
              child: const Text('Try again'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartLearningView() {
    return RefreshIndicator(
      onRefresh: _refreshLessons,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          Icon(
            Icons.school_outlined,
            size: 86,
            color: AppColors.ocean.withOpacity(0.25),
          ),
          const SizedBox(height: 18),
          const Text(
            'Start learning',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'You don\'t have any lessons yet. Once your instructor shares a weekly plan, it will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go(AppRoutes.findInstructor),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ocean,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text('Find Instructor'),
            ),
          ),
        ],
      ),
    );
  }

}
