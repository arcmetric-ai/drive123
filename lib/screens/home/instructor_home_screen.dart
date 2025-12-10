import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../models/lesson_model.dart';
import '../../services/app_notifier.dart';
import '../../services/supabase_service.dart';
import '../../widgets/glass_panel.dart';
import '../instructor/instructor_requests_screen.dart';
import '../home/instructor_notifications_sheet.dart';
import '../profile/profile_screen.dart';

LessonStatus _deriveLessonStatus(Map<String, dynamic> lesson) {
  final baseStatus = LessonModel.parseStatus((lesson['status'] ?? '').toString());
  final scheduledStr = lesson['scheduled_at']?.toString();
  final scheduled = scheduledStr != null ? DateTime.tryParse(scheduledStr) : null;
  if (scheduled == null) return baseStatus;

  double? durationHours;
  final hours = lesson['duration_hours'];
  if (hours is num) {
    durationHours = hours.toDouble();
  } else if (lesson['duration_minutes'] is num) {
    durationHours = (lesson['duration_minutes'] as num).toDouble() / 60.0;
  }

  return LessonModel.deriveStatus(
    scheduledDate: scheduled.toLocal(),
    startTime: (lesson['start_time'] ?? '').toString(),
    endTime: (lesson['end_time'] ?? '').toString(),
    durationHours: durationHours,
    fallbackStatus: baseStatus,
  );
}

Map<String, dynamic> _withDerivedLessonStatus(Map<String, dynamic> lesson) {
  final derived = _deriveLessonStatus(lesson);
  if ((lesson['status'] ?? '').toString() == derived.name) return lesson;
  return {...lesson, 'status': derived.name};
}

class InstructorHomeScreen extends StatefulWidget {
  const InstructorHomeScreen({super.key});

  @override
  State<InstructorHomeScreen> createState() => _InstructorHomeScreenState();
}

class _InstructorHomeScreenState extends State<InstructorHomeScreen> {
  int _selectedIndex = 0;
  bool _reduceMotion = false;

  static const _notificationsViewedKey = 'drive_t_instructor_notifications_viewed_v1';
  static const _reduceMotionKey = 'drive_t_instructor_reduce_motion';

  void _onTabTap(int index) {
    setState(() => _selectedIndex = index);
  }

  String get _instructorName {
    final user = SupabaseService.currentUser;
    final metadata = user?.userMetadata;
    final first = metadata?['first_name'] as String?;
    final last = metadata?['last_name'] as String?;
    if (first != null && first.isNotEmpty) {
      return last != null && last.isNotEmpty ? '$first $last' : first;
    }
    final email = user?.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'there';
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _DashboardTab(
        name: _instructorName,
        reduceMotion: _reduceMotion,
        onToggleMotion: _toggleMotion,
        onOpenBookings: () => _onTabTap(2),
      ),
      _ScheduleTab(
        reduceMotion: _reduceMotion,
        onToggleMotion: _toggleMotion,
      ),
      _BookingsTab(
        reduceMotion: _reduceMotion,
        onToggleMotion: _toggleMotion,
      ),
      _StudentsTab(
        reduceMotion: _reduceMotion,
        onToggleMotion: _toggleMotion,
      ),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: _GlassBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onTabTap,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadMotionPreference();
  }

  Future<void> _loadMotionPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_reduceMotionKey);
    if (!mounted) return;
    setState(() => _reduceMotion = stored ?? false);
  }

  Future<void> _toggleMotion() async {
    final next = !_reduceMotion;
    setState(() => _reduceMotion = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reduceMotionKey, next);
  }
}

class _DashboardTab extends StatefulWidget {
  final String name;
  final bool reduceMotion;
  final VoidCallback onToggleMotion;
  final VoidCallback onOpenBookings;

  const _DashboardTab({
    required this.name,
    required this.reduceMotion,
    required this.onToggleMotion,
    required this.onOpenBookings,
  });

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _upcomingLessons = [];
  List<Map<String, dynamic>> _requests = [];
  int _monthlyClasses = 0;
  int _totalClasses = 0;
  String? _profileImageUrl;
  List<InstructorNotification> _notifications = [];
  String? _notificationsError;
  bool _notificationsLoading = false;
  DateTime? _notificationsLastViewedAt;
  static const _notificationsViewedKey =
      'drive_t_instructor_notifications_viewed_v1';
  late final Timer _bgTimer;
  bool _bgShift = false;

  String? get _userId => SupabaseService.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _loadNotificationsLastViewed();
    _load();
    _bgTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        setState(() => _bgShift = !_bgShift);
      }
    });
  }

  @override
  void dispose() {
    _bgTimer.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = _userId;
    if (userId == null) {
      setState(() {
        _loading = false;
        _monthlyClasses = 0;
        _totalClasses = 0;
        _profileImageUrl = null;
        _notifications = [];
        _notificationsError = 'Instructor not found.';
        _notificationsLoading = false;
      });
      return;
    }

    final now = DateTime.now();
    final notificationsRangeStart = now.subtract(const Duration(days: 1));
    final notificationsRangeEnd = now.add(const Duration(days: 1));

    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        SupabaseService.getUpcomingLessonsForInstructor(userId),
        SupabaseService.getLessonRequestsForInstructor(userId),
        SupabaseService.getInstructorEarningsSummary(userId),
        SupabaseService.getRawProfile(userId),
        SupabaseService.getInstructorLessonsForRange(
          userId: userId,
          start: notificationsRangeStart,
          end: notificationsRangeEnd,
        ),
      ]);

      final lessons = (results[0] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map(_withDerivedLessonStatus)
          .toList();
      final requests = List<Map<String, dynamic>>.from(results[1] as List);
      final summary = Map<String, dynamic>.from(results[2] as Map);
      final profile = results[3] as Map<String, dynamic>?;
      final lessonsForNotifications = (results[4] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map(_withDerivedLessonStatus)
          .toList();

      final pendingRequests = requests
          .where((request) =>
              ((request['status'] as String?) ?? '').toLowerCase() == 'pending')
          .toList();
      final metadataImage = SupabaseService
          .currentUser?.userMetadata?['profile_image_url'] as String?;
      final derivedProfileImage = () {
        final primary = profile?['profile_image_url'] as String?;
        final avatar = profile?['avatar_url'] as String?;
        final fallback = profile?['profile_image'] as String?;
        final metadata = metadataImage;
        return [primary, avatar, fallback, metadata]
            .whereType<String>()
            .map((value) => value.trim())
            .firstWhere((value) => value.isNotEmpty, orElse: () => '');
      }();
      final notifications =
          _buildInstructorNotifications(requests, lessonsForNotifications);

      setState(() {
        _upcomingLessons = lessons
            .where((lesson) =>
                _deriveLessonStatus(lesson) != LessonStatus.completed &&
                _deriveLessonStatus(lesson) != LessonStatus.cancelled)
            .toList();
        _requests = pendingRequests;
        _monthlyClasses = summary['monthlyClasses'] is int
            ? summary['monthlyClasses'] as int
            : (summary['monthlyClasses'] as num?)?.toInt() ?? 0;
        _totalClasses = summary['totalClasses'] is int
            ? summary['totalClasses'] as int
            : (summary['totalClasses'] as num?)?.toInt() ?? 0;
        _profileImageUrl =
            derivedProfileImage.isNotEmpty ? derivedProfileImage : null;
        _notifications = notifications;
        _notificationsError = null;
        _notificationsLoading = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _monthlyClasses = 0;
        _totalClasses = 0;
        _profileImageUrl = null;
        _notifications = [];
        _notificationsError =
            'Unable to load notifications right now. Please try again soon.';
        _notificationsLoading = false;
      });
    }
  }

  String get _profileInitials {
    final name = widget.name.trim();
    if (name.isEmpty) return 'I';
    final parts =
        name.split(RegExp(r'\s+')).where((segment) => segment.isNotEmpty);
    final initials = parts.take(2).map((segment) => segment[0].toUpperCase());
    final joined = initials.join();
    return joined.isNotEmpty ? joined : 'I';
  }

  bool get _hasNotificationBadge {
    return _notifications.any((notification) => _isNotificationUnread(notification));
  }

  Future<void> _refreshNotifications() async {
    final userId = _userId;
    if (userId == null) {
      setState(() {
        _notifications = [];
        _notificationsError = 'Unable to load notifications.';
        _notificationsLoading = false;
      });
      return;
    }
    setState(() {
      _notificationsLoading = true;
      _notificationsError = null;
    });
    try {
      final fetched = await _fetchNotificationsData(userId);
      if (!mounted) return;
      setState(() {
        _notifications = fetched;
        _notificationsLoading = false;
        _notificationsError = null;
      });
      await _markNotificationsViewed();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notificationsLoading = false;
        _notificationsError =
            'Unable to load notifications right now. Please try again soon.';
      });
    }
  }

  Future<void> _loadNotificationsLastViewed() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_notificationsViewedKey);
    if (!mounted || stored == null) return;
    final parsed = DateTime.tryParse(stored);
    if (parsed == null) return;
    setState(() => _notificationsLastViewedAt = parsed);
  }

  Future<void> _markNotificationsViewed() async {
    final now = DateTime.now();
    if (mounted) {
      setState(() => _notificationsLastViewedAt = now);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notificationsViewedKey, now.toIso8601String());
  }

  bool _isNotificationUnread(InstructorNotification notification) {
    final now = DateTime.now();
    final effective =
        notification.timestamp.isAfter(now) ? now : notification.timestamp;
    if (_notificationsLastViewedAt == null) return true;
    return effective.isAfter(_notificationsLastViewedAt!);
  }

  Future<List<InstructorNotification>> _fetchNotificationsData(
      String userId) async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 1));
    final end = now.add(const Duration(days: 1));
    final results = await Future.wait<dynamic>([
      SupabaseService.getLessonRequestsForInstructor(userId),
      SupabaseService.getInstructorLessonsForRange(
        userId: userId,
        start: start,
        end: end,
      ),
    ]);
    final requests = List<Map<String, dynamic>>.from(results[0] as List);
    final lessons = (results[1] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .map(_withDerivedLessonStatus)
        .toList();
    return _buildInstructorNotifications(requests, lessons);
  }

  List<InstructorNotification> _buildInstructorNotifications(
    List<Map<String, dynamic>> requests,
    List<Map<String, dynamic>> lessons,
  ) {
    final now = DateTime.now();
    final map = <String, InstructorNotification>{};

    for (final request in requests) {
      final status = (request['status'] as String?)?.toLowerCase();
      if (status != 'pending') continue;
      final createdAt = _parseDateTime(request['created_at']) ?? now;
      if (now.difference(createdAt).inDays > 30) continue;
      final id = 'request-${request['id']}';
      final learnerName = _resolveRequestLearnerName(request);
      map[id] = InstructorNotification(
        id: id,
        title: 'You received a new Learner request',
        message: 'You received a new Learner request from $learnerName.',
        timestamp: createdAt,
        icon: Icons.person_add_alt_1,
        color: AppColors.primaryBlue,
      );
    }

    for (final lesson in lessons) {
      final lessonId = lesson['id']?.toString() ?? '';
      if (lessonId.isEmpty) continue;
      final status = _deriveLessonStatus(lesson);
      final scheduledAt = _parseDateTime(lesson['scheduled_at']);
      final startTime = _combineDateAndTime(scheduledAt, lesson['start_time']);
      DateTime? endTime = _combineDateAndTime(scheduledAt, lesson['end_time']);
      if (endTime == null && startTime != null) {
        final durationHours = (lesson['duration_hours'] as num?)?.toDouble();
        if (durationHours != null && durationHours > 0) {
          endTime =
              startTime.add(Duration(minutes: (durationHours * 60).round()));
        }
      }
      final learnerName = _resolveLessonLearnerName(lesson['learner']);
      final timeRangeLabel = _formatLessonTimeRange(startTime, endTime);
      final dayLabel = startTime != null
          ? DateFormat('MMM d').format(startTime)
          : 'the scheduled time';

      if (status == LessonStatus.scheduled && startTime != null) {
        final diffMinutes = startTime.difference(now).inMinutes;
        if (diffMinutes >= 0 && diffMinutes <= 15) {
          final id = 'lesson-reminder-$lessonId';
          final reminderTimestamp =
              startTime.subtract(const Duration(minutes: 15));
          map[id] = InstructorNotification(
            id: id,
            title: 'You have a class in 15 mins reminder',
            message:
                'You have a class with $learnerName on $dayLabel at $timeRangeLabel in 15 minutes.',
            timestamp:
                reminderTimestamp.isAfter(now) ? reminderTimestamp : startTime,
            icon: Icons.alarm,
            color: AppColors.golden,
          );
        }
      }

      if (status == LessonStatus.inProgress) {
        final id = 'lesson-started-$lessonId';
        final timestamp = startTime ?? now;
        map[id] = InstructorNotification(
          id: id,
          title: 'Your class has started',
          message:
              'Your class with $learnerName on $dayLabel at $timeRangeLabel has started.',
          timestamp: timestamp,
          icon: Icons.play_circle_outline,
          color: AppColors.primaryBlue,
        );
      }

      if (status == LessonStatus.completed) {
        final updatedAt = _parseDateTime(lesson['updated_at']) ?? now;
        if (now.difference(updatedAt).inDays <= 7) {
          final id = 'lesson-ended-$lessonId';
          final timestamp = endTime ?? updatedAt;
          map[id] = InstructorNotification(
            id: id,
            title: 'Your class has ended',
            message:
                'Your class with $learnerName on $dayLabel at $timeRangeLabel has ended.',
            timestamp: timestamp,
            icon: Icons.check_circle_outline,
            color: AppColors.success,
          );
        }
      }
    }

    final notifications = map.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return notifications;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      return parsed?.toLocal();
    }
    return null;
  }

  DateTime? _combineDateAndTime(DateTime? date, dynamic rawTime) {
    if (date == null) return null;
    final timeString = (rawTime as String?)?.trim();
    if (timeString == null || timeString.isEmpty) return date;
    final parts = timeString.split(':');
    if (parts.length < 2) return date;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return date;
    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    return combined.toLocal();
  }

  String _formatLessonTimeRange(DateTime? start, DateTime? end) {
    if (start == null) return 'the scheduled time';
    final startLabel = DateFormat('h:mm a').format(start);
    if (end != null && end.isAfter(start)) {
      final endLabel = DateFormat('h:mm a').format(end);
      return '$startLabel – $endLabel';
    }
    return startLabel;
  }

  String _resolveRequestLearnerName(Map<String, dynamic> request) {
    final hydrated = (request['learner_name'] as String?)?.trim();
    if (hydrated != null && hydrated.isNotEmpty) return hydrated;
    final learner = request['learner'];
    if (learner is Map<String, dynamic>) {
      final candidate = _resolveLessonLearnerName(learner);
      if (candidate != 'Learner') return candidate;
    }
    final first = (request['requested_first_name'] as String?)?.trim();
    final last = (request['requested_last_name'] as String?)?.trim();
    final combined = [first, last]
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .join(' ');
    if (combined.isNotEmpty) return combined;
    final name = (request['requested_name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = (request['requested_email'] as String?)?.trim();
    if (email != null && email.isNotEmpty) return email;
    return 'Learner';
  }

  String _resolveLessonLearnerName(dynamic learner) {
    if (learner is Map<String, dynamic>) {
      final direct = (learner['name'] as String?)?.trim();
      if (direct != null && direct.isNotEmpty) return direct;
      final first = (learner['first_name'] as String?)?.trim() ?? '';
      final last = (learner['last_name'] as String?)?.trim() ?? '';
      final combined = '$first $last'.trim();
      if (combined.isNotEmpty) return combined;
      final email = (learner['email'] as String?)?.trim();
      if (email != null && email.isNotEmpty) return email;
    } else if (learner is String && learner.trim().isNotEmpty) {
      return learner.trim();
    }
    return 'Learner';
  }

  void _openProfile() {
    GoRouter.of(context).push(AppRoutes.profile);
  }

  Future<void> _handleOpenNotifications() async {
    await _refreshNotifications();
    await _markNotificationsViewed();
    if (!mounted) return;

    var sheetNotifications = List<InstructorNotification>.from(_notifications);
    var sheetError = _notificationsError;
    var sheetLoading = _notificationsLoading;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> refresh() async {
              setModalState(() {
                sheetLoading = true;
                sheetError = null;
              });
              try {
                final userId = _userId;
                if (userId == null) {
                  setModalState(() {
                    sheetLoading = false;
                    sheetError = 'Unable to load notifications.';
                  });
                  return;
                }
                final fetched = await _fetchNotificationsData(userId);
                if (!mounted) return;
                setModalState(() {
                  sheetNotifications = fetched;
                  sheetLoading = false;
                });
                setState(() {
                  _notifications = fetched;
                  _notificationsError = null;
                });
                await _markNotificationsViewed();
              } catch (_) {
                setModalState(() {
                  sheetLoading = false;
                  sheetError =
                      'Unable to load notifications right now. Please try again soon.';
                });
              }
            }

            return InstructorNotificationsSheet(
              notifications: sheetNotifications,
              isLoading: sheetLoading,
              error: sheetError,
              onRefresh: refresh,
              onMarkRead: _markNotificationsViewed,
              isUnread: _isNotificationUnread,
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> _lessonsForToday() {
    final today = DateTime.now();
    return _upcomingLessons.where((lesson) {
      final scheduledStr = lesson['scheduled_at'] as String?;
      if (scheduledStr == null) return false;
      final parsed = DateTime.tryParse(scheduledStr);
      if (parsed == null) return false;
      final local = parsed.toLocal();
      return local.year == today.year &&
          local.month == today.month &&
          local.day == today.day;
    }).toList();
  }

  double _totalHoursForLessons(List<Map<String, dynamic>> lessons) {
    var total = 0.0;
    for (final lesson in lessons) {
      final hours = (lesson['duration_hours'] as num?)?.toDouble();
      if (hours != null && hours > 0) {
        total += hours;
        continue;
      }
      final minutes = (lesson['duration_minutes'] as num?)?.toDouble();
      if (minutes != null && minutes > 0) {
        total += minutes / 60.0;
      } else {
        total += 1.0;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final todayLessons = _lessonsForToday();
    final scheduleSummary = todayLessons.isEmpty
        ? 'No lessons scheduled today'
        : '${todayLessons.length} lesson${todayLessons.length == 1 ? '' : 's'} • ${_totalHoursForLessons(todayLessons).toStringAsFixed(1)} hrs';
    final activeLearners = _upcomingLessons
        .map((lesson) => lesson['learner']?['id'] ?? lesson['learner_id'])
        .where((id) => id != null)
        .toSet()
        .length;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 68,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.primaryBlue,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: GestureDetector(
            onTap: _openProfile,
            child: CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.ocean.withOpacity(0.12),
              backgroundImage: _profileImageUrl != null
                  ? NetworkImage(_profileImageUrl!)
                  : null,
              child: _profileImageUrl != null
                  ? null
                  : Text(
                      _profileInitials,
                      style: const TextStyle(
                        color: AppColors.ocean,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
        titleSpacing: 0,
        title: Text(
          'Drive - T Instructor',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: _handleOpenNotifications,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if (_hasNotificationBadge)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: widget.reduceMotion
                ? 'Enable animated background'
                : 'Reduce motion (static background)',
            onPressed: widget.onToggleMotion,
            icon: Icon(
              widget.reduceMotion
                  ? Icons.visibility
                  : Icons.visibility_off_outlined,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          widget.reduceMotion
              ? Container(color: Colors.white)
              : AnimatedContainer(
                  duration: const Duration(milliseconds: 1200),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE0F2FF),
                        Color(0xFFF6F3FF),
                        Color(0xFFE7F2FF),
                      ],
                    ),
                ),
          ),
          if (!widget.reduceMotion) ...[
            AnimatedPositioned(
              duration: const Duration(milliseconds: 1800),
              top: _bgShift ? 50 : 140,
              left: _bgShift ? -60 : 20,
              child: const _BlurCircle(
                diameter: 220,
                color: Color(0xFFBCE7FF),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 1800),
              bottom: _bgShift ? 80 : 20,
              right: _bgShift ? -50 : 10,
              child: const _BlurCircle(
                diameter: 260,
                color: Color(0xFFCEC4FF),
              ),
            ),
          ],
          Positioned.fill(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 120, 20, 20),
                      children: [
                        _WelcomeCard(
                          name: widget.name,
                          scheduleSummary: scheduleSummary,
                          totalClasses: _totalClasses,
                        ),
                        const SizedBox(height: 12),
                        _StatsRow(
                          metrics: [
                            _StatMetric(
                              icon: Icons.calendar_today_outlined,
                              label: "Today's Lessons",
                              value: todayLessons.length.toString(),
                              color: AppColors.primaryBlue,
                            ),
                            _StatMetric(
                              icon: Icons.group_outlined,
                              label: 'Active Learners',
                              value: activeLearners.toString(),
                              color: const Color(0xFF23C16B),
                            ),
                            _StatMetric(
                              icon: Icons.event_available_outlined,
                              label: 'Monthly Lessons',
                              value: _monthlyClasses.toString(),
                              color: const Color(0xFF6B5AE0),
                            ),
                            _StatMetric(
                              icon: Icons.insights_outlined,
                              label: 'Total Lessons',
                              value: _totalClasses.toString(),
                              color: const Color(0xFFFF8A65),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _RequestsCard(
                          requests: _requests,
                        ),
                        const SizedBox(height: 20),
                        _UpcomingLessonsCard(
                          lessons: todayLessons,
                          onLessonSelected: (lesson) {
                            GoRouter.of(context).push(
                                AppRoutes.instructorLessonDetail,
                                extra: lesson);
                          },
                          onViewAll: widget.onOpenBookings,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleTab extends StatefulWidget {
  const _ScheduleTab({
    required this.reduceMotion,
    required this.onToggleMotion,
  });

  final bool reduceMotion;
  final VoidCallback onToggleMotion;

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  final ValueNotifier<List<_LessonEvent>> _selectedEvents =
      ValueNotifier<List<_LessonEvent>>(<_LessonEvent>[]);
  final Map<DateTime, List<_LessonEvent>> _eventsByDay = {};
  bool _loading = true;
  bool _error = false;
  late final Timer _bgTimer;
  bool _bgShift = false;

  @override
  void initState() {
    super.initState();
    final today = _normalizeDate(DateTime.now());
    _focusedDay = today;
    _selectedDay = today;
    _loadLessonsForMonth(_focusedDay);
    AppNotifier.instance.addListener(_handleLessonsChanged);
    _bgTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        setState(() => _bgShift = !_bgShift);
      }
    });
  }

  @override
  void dispose() {
    AppNotifier.instance.removeListener(_handleLessonsChanged);
    _selectedEvents.dispose();
    _bgTimer.cancel();
    super.dispose();
  }

  void _handleLessonsChanged() {
    _loadLessonsForMonth(_focusedDay, silent: true);
  }

  Future<void> _loadLessonsForMonth(DateTime reference,
      {bool silent = false}) async {
    final instructorId = SupabaseService.currentUser?.id;
    if (instructorId == null) {
      if (!silent) {
        setState(() {
          _loading = false;
          _error = true;
        });
      } else {
        setState(() {
          _error = true;
        });
      }
      _selectedEvents.value = const [];
      return;
    }

    if (!silent) {
      setState(() {
        _loading = true;
        _error = false;
      });
    } else {
      setState(() {
        _error = false;
      });
    }

    final monthStart = DateTime(reference.year, reference.month, 1);
    final monthEnd = DateTime(reference.year, reference.month + 1, 1);

    try {
      final rows = await SupabaseService.getInstructorLessonsForRange(
        userId: instructorId,
        start: monthStart,
        end: monthEnd,
      );

      final map = <DateTime, List<_LessonEvent>>{};
      for (final row in rows) {
        final event = _LessonEvent.fromRow(row);
        if (event == null) continue;
        final key = _normalizeDate(event.start);
        map.putIfAbsent(key, () => <_LessonEvent>[]).add(event);
      }
      map.forEach(
        (key, value) => value.sort((a, b) => a.start.compareTo(b.start)),
      );

      if (!mounted) return;
      setState(() {
        _eventsByDay
          ..clear()
          ..addAll(map);
        _loading = false;
      });
      _selectedEvents.value = List<_LessonEvent>.from(
        _eventsByDay[_selectedDay] ?? const <_LessonEvent>[],
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  List<_LessonEvent> _eventsForDay(DateTime day) {
    final key = _normalizeDate(day);
    final events = _eventsByDay[key];
    return events != null ? List<_LessonEvent>.from(events) : <_LessonEvent>[];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final normalized = _normalizeDate(selectedDay);
    setState(() {
      _selectedDay = normalized;
      _focusedDay = _normalizeDate(focusedDay);
    });
    _selectedEvents.value = List<_LessonEvent>.from(
      _eventsByDay[normalized] ?? const <_LessonEvent>[],
    );
  }

  void _onCalendarPageChanged(DateTime focusedDay) {
    final normalized = _normalizeDate(focusedDay);
    _focusedDay = normalized;
    _loadLessonsForMonth(normalized, silent: true);
  }

  void _onFormatChanged(CalendarFormat format) {
    if (_calendarFormat != format) {
      setState(() => _calendarFormat = format);
    }
  }

  Future<void> _refresh() => _loadLessonsForMonth(_focusedDay, silent: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Schedule'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: widget.reduceMotion
                ? 'Enable animated background'
                : 'Reduce motion (static background)',
            onPressed: widget.onToggleMotion,
            icon: Icon(
              widget.reduceMotion
                  ? Icons.visibility
                  : Icons.visibility_off_outlined,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          widget.reduceMotion
              ? Container(color: Colors.white)
              : AnimatedContainer(
                  duration: const Duration(milliseconds: 1200),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE0F2FF),
                        Color(0xFFF6F3FF),
                        Color(0xFFE7F2FF),
                      ],
                    ),
                  ),
                ),
          if (!widget.reduceMotion) ...[
            AnimatedPositioned(
              duration: const Duration(milliseconds: 1800),
              top: _bgShift ? 60 : 140,
              left: _bgShift ? -40 : 30,
              child: const _BlurCircle(
                diameter: 200,
                color: Color(0xFFBCE7FF),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 1800),
              bottom: _bgShift ? 40 : 100,
              right: _bgShift ? -30 : 20,
              child: const _BlurCircle(
                diameter: 240,
                color: Color(0xFFCEC4FF),
              ),
            ),
          ],
          Positioned.fill(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error
                    ? _ScheduleErrorView(
                        onRetry: () => _loadLessonsForMonth(_focusedDay),
                      )
                    : SafeArea(
                        child: RefreshIndicator(
                          color: AppColors.primaryBlue,
                          onRefresh: _refresh,
                          child: ValueListenableBuilder<List<_LessonEvent>>(
                            valueListenable: _selectedEvents,
                            builder: (context, events, _) {
                              final summaryText = events.isEmpty
                                  ? 'No lessons scheduled'
                                  : '${events.length} ${events.length == 1 ? 'lesson' : 'lessons'} scheduled';
                              return SingleChildScrollView(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(0, 0, 0, 40),
                                child: Column(
                                  children: [
                                    _buildCalendarCard(),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          20, 12, 20, 4),
                                      child: GlassPanel(
                                        borderRadius:
                                            BorderRadius.circular(24),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                          vertical: 14,
                                        ),
                                        opacity: 0.42,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    DateFormat.yMMMMEEEEd()
                                                        .format(_selectedDay),
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          AppColors.primaryBlue,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    summaryText,
                                                    style: const TextStyle(
                                                      color: Colors.black54,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            FilledButton.icon(
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.primaryBlue,
                                                foregroundColor: Colors.white,
                                                shape:
                                                    const StadiumBorder(),
                                              ),
                                              onPressed: () {
                                                GoRouter.of(context).push(
                                                    AppRoutes
                                                        .instructorAvailability);
                                              },
                                              icon: const Icon(
                                                  Icons.calendar_view_week),
                                              label:
                                                  const Text('Weekly planner'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (events.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20),
                                        child: GlassPanel(
                                          borderRadius:
                                              BorderRadius.circular(26),
                                          opacity: 0.42,
                                          padding: const EdgeInsets.all(24),
                                          child: _EmptyState(
                                            icon: Icons
                                                .event_available_outlined,
                                            title: 'No lessons scheduled',
                                            description:
                                                'Use the weekly planner to add lessons for this day.',
                                            primaryActionText:
                                                'Open weekly planner',
                                            onPrimaryAction: () {
                                              GoRouter.of(context).push(
                                                  AppRoutes
                                                      .instructorAvailability);
                                            },
                                          ),
                                        ),
                                      )
                                    else
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20),
                                        child: Column(
                                          children: [
                                            for (int i = 0;
                                                i < events.length;
                                                i++) ...[
                                              if (i > 0)
                                                const SizedBox(height: 14),
                                              _ScheduleEventTile(
                                                  event: events[i]),
                                            ],
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GlassPanel(
        borderRadius: BorderRadius.circular(28),
        opacity: 0.64,
        tintColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: TableCalendar<_LessonEvent>(
          firstDay: DateTime(_focusedDay.year - 1, 1, 1),
          lastDay: DateTime(_focusedDay.year + 1, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          startingDayOfWeek: StartingDayOfWeek.monday,
          selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
          eventLoader: _eventsForDay,
          onDaySelected: _onDaySelected,
          onFormatChanged: _onFormatChanged,
          onPageChanged: _onCalendarPageChanged,
          calendarStyle: CalendarStyle(
            outsideDaysVisible: false,
            isTodayHighlighted: true,
            todayDecoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            selectedDecoration: const BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: const TextStyle(color: Colors.white),
            weekendTextStyle: const TextStyle(fontWeight: FontWeight.w600),
            markersAlignment: Alignment.bottomCenter,
            markerDecoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          headerStyle: HeaderStyle(
            formatButtonVisible: true,
            titleCentered: true,
            formatButtonShowsNext: false,
            titleTextStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryBlue,
            ),
            formatButtonDecoration: BoxDecoration(
              color: Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(999),
            ),
            formatButtonTextStyle: const TextStyle(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
            leftChevronIcon:
                const Icon(Icons.chevron_left, color: AppColors.primaryBlue),
            rightChevronIcon:
                const Icon(Icons.chevron_right, color: AppColors.primaryBlue),
          ),
          availableCalendarFormats: const {
            CalendarFormat.month: 'Month',
            CalendarFormat.week: 'Week',
          },
        ),
      ),
    );
  }
}

class _ScheduleEventTile extends StatelessWidget {
  final _LessonEvent event;

  const _ScheduleEventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(event.status);
    final subtitleItems = <String>[];
    if ((event.focus ?? '').trim().isNotEmpty) {
      subtitleItems.add(event.focus!.trim());
    }
    if ((event.location ?? '').trim().isNotEmpty) {
      subtitleItems.add(event.location!.trim());
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => GoRouter.of(context)
            .push(AppRoutes.instructorLessonDetail, extra: event.raw),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    event.timeLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      event.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                event.learnerName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitleItems.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitleItems.join(' \u00B7 '),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized == 'scheduled' || normalized == 'active') {
      return AppColors.primaryBlue;
    }
    if (normalized == 'completed' || normalized == 'done') {
      return AppColors.success;
    }
    if (normalized == 'cancelled' || normalized == 'canceled') {
      return AppColors.error;
    }
    return Colors.grey[600]!;
  }
}

class _ScheduleCard extends StatelessWidget {
  final String learner;
  final String time;
  final String focus;
  final String location;
  final String avatarUrl;
  final VoidCallback? onTap;

  const _ScheduleCard({
    required this.learner,
    required this.time,
    required this.focus,
    required this.location,
    required this.avatarUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedName = learner.trim();
    final initial =
        trimmedName.isNotEmpty ? trimmedName[0].toUpperCase() : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primaryBlue.withOpacity(0.12),
                    backgroundImage:
                        avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          learner,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          focus,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      time,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pickup: $location',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonEvent {
  _LessonEvent({
    required this.id,
    required this.start,
    required this.end,
    required this.status,
    required this.learnerName,
    required this.focus,
    required this.location,
    required this.raw,
  });

  final String? id;
  final DateTime start;
  final DateTime end;
  final String status;
  final String learnerName;
  final String? focus;
  final String? location;
  final Map<String, dynamic> raw;

  String get timeLabel =>
      '${DateFormat('h:mm a').format(start)} \u2013 ${DateFormat('h:mm a').format(end)}';

  String get statusLabel {
    final normalized = status.trim().toLowerCase();
    if (normalized.isEmpty) return 'Scheduled';
    if (normalized == 'inprogress' || normalized == 'in_progress') {
      return 'In progress';
    }
    return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
  }

  static _LessonEvent? fromRow(Map<String, dynamic> row) {
    if (row['scheduled_at'] == null) return null;
    final scheduledAt =
        DateTime.tryParse(row['scheduled_at'].toString())?.toLocal();
    if (scheduledAt == null) return null;

    final data = Map<String, dynamic>.from(row);

    DateTime start = scheduledAt;
    DateTime end;

    double durationHours = 1;
    final rawDuration = data['duration_hours'];
    if (rawDuration is num) {
      durationHours = rawDuration.toDouble();
    } else if (data['duration_minutes'] is num) {
      durationHours = (data['duration_minutes'] as num).toDouble() / 60.0;
    }
    if (durationHours < 0.25) {
      durationHours = 0.25;
    }

    DateTime? merge(String? value) {
      if (value == null || value.isEmpty) return null;
      final parts = value.split(':');
      if (parts.length < 2) return null;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return null;
      return DateTime(
        scheduledAt.year,
        scheduledAt.month,
        scheduledAt.day,
        hour,
        minute,
      );
    }

    final startCandidate = merge(data['start_time']?.toString());
    if (startCandidate != null) {
      start = startCandidate;
    }

    final endCandidate = merge(data['end_time']?.toString());
    if (endCandidate != null) {
      end = endCandidate;
    } else {
      end = start.add(Duration(minutes: (durationHours * 60).round()));
    }

    final learnerData = data['learner'];
    final learnerName = _readLearnerName(data);

    final focus = (data['focus'] ?? '').toString();
    final location = (data['pickup_location'] ?? '').toString();
    final baseStatus = LessonModel.parseStatus((data['status'] ?? '').toString());
    final derivedStatus = LessonModel.deriveStatus(
      scheduledDate: scheduledAt.toLocal(),
      startTime: (data['start_time'] ?? '').toString(),
      endTime: (data['end_time'] ?? '').toString(),
      durationHours: durationHours,
      fallbackStatus: baseStatus,
    );
    final status = derivedStatus.name;

    return _LessonEvent(
      id: data['id']?.toString(),
      start: start,
      end: end,
      status: status,
      learnerName: learnerName,
      focus: focus.trim().isEmpty ? null : focus.trim(),
      location: location.trim().isEmpty ? null : location.trim(),
      raw: data,
    );
  }
}

class _ScheduleErrorView extends StatelessWidget {
  const _ScheduleErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppColors.primaryBlue),
            const SizedBox(height: 16),
            const Text(
              'Unable to load schedule',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingsErrorView extends StatelessWidget {
  const _BookingsErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: GlassPanel(
          borderRadius: BorderRadius.circular(28),
          opacity: 0.42,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.event_busy,
                size: 48,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(height: 16),
              const Text(
                'Unable to load bookings',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookingsTab extends StatefulWidget {
  const _BookingsTab({
    super.key,
    required this.reduceMotion,
    required this.onToggleMotion,
  });

  final bool reduceMotion;
  final VoidCallback onToggleMotion;

  @override
  State<_BookingsTab> createState() => _BookingsTabState();
}

String _readLearnerName(Map<String, dynamic> data) {
  String? _clean(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? _fromProfile(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    final first = _clean(profile['first_name']);
    final last = _clean(profile['last_name']);
    final name = [first, last].whereType<String>().join(' ').trim();
    if (name.isNotEmpty) return name;
    final email = _clean(profile['email']);
    if (email != null) return email;
    final fallback = _clean(profile['name']);
    if (fallback != null) return fallback;
    return null;
  }

  Map<String, dynamic>? learnerMap;
  if (data['learner'] is Map) {
    learnerMap = (data['learner'] as Map)
        .map((key, value) => MapEntry(key.toString(), value));
  }

  Map<String, dynamic>? learnerProfile;
  if (data['learner_profile'] is Map) {
    learnerProfile = (data['learner_profile'] as Map)
        .map((key, value) => MapEntry(key.toString(), value));
  }

  Map<String, dynamic>? nestedProfile;
  if (learnerProfile != null && learnerProfile['profile'] is Map) {
    nestedProfile = (learnerProfile['profile'] as Map)
        .map((key, value) => MapEntry(key.toString(), value));
  }

  final learnerString = _clean(data['learner']);
  if (learnerString != null &&
      learnerMap == null &&
      learnerProfile == null &&
      nestedProfile == null) {
    return learnerString;
  }

  final requestedName = () {
    final first = _clean(data['requested_first_name']);
    final last = _clean(data['requested_last_name']);
    final combined = [first, last].whereType<String>().join(' ').trim();
    if (combined.isNotEmpty) return combined;
    return _clean(data['requested_name']);
  }();

  return _fromProfile(learnerMap) ??
      _fromProfile(nestedProfile ?? learnerProfile) ??
      _clean(data['name']) ??
      _clean(data['learner_name']) ??
      requestedName ??
      _clean(data['learner_email']) ??
      'Learner';
}

class _BookingsTabState extends State<_BookingsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  bool _error = false;
  DateTime _currentMonth = DateTime.now();
  final Map<DateTime, List<_LessonSlot>> _slotsByDay = {};
  late final Timer _bgTimer;
  bool _bgShift = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLessons();
    _bgTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        setState(() => _bgShift = !_bgShift);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bgTimer.cancel();
    super.dispose();
  }

  Future<void> _loadLessons() async {
    final instructorId = SupabaseService.currentUser?.id;
    if (instructorId == null) {
      setState(() {
        _loading = false;
        _error = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = false;
      _slotsByDay.clear();
    });

    final now = DateTime.now();
    final baseMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final start = baseMonth.subtract(const Duration(days: 7));
    // include a buffer into the following month to cover the calendar view
    final end =
        DateTime(baseMonth.year, baseMonth.month + 1, 1).add(const Duration(days: 7));

    try {
      final lessons = await SupabaseService.getInstructorLessonsForRange(
        userId: instructorId,
        start: start,
        end: end,
      );

      final map = <DateTime, List<_LessonSlot>>{};
      for (final lesson in lessons) {
        final status = _deriveLessonStatus(lesson);
        if (status != LessonStatus.scheduled &&
            status != LessonStatus.inProgress) continue;
        final scheduledStr = lesson['scheduled_at'] as String?;
        if (scheduledStr == null) continue;
        final scheduled = DateTime.tryParse(scheduledStr);
        if (scheduled == null) continue;
        final localStart = scheduled.toLocal();

        DateTime startTime = localStart;
        DateTime endTime;
        final startTimeStr = lesson['start_time'] as String?;
        final endTimeStr = lesson['end_time'] as String?;
        double durationHours = 1.0;
        final rawHours = lesson['duration_hours'];
        if (rawHours is num) {
          durationHours = rawHours.toDouble();
        } else if (lesson['duration_minutes'] is num) {
          durationHours = (lesson['duration_minutes'] as num).toDouble() / 60.0;
        }
        if (durationHours < 1) {
          durationHours = 1.0;
        }

        if (startTimeStr != null && endTimeStr != null) {
          final parsedStart = _mergeDateWithTime(localStart, startTimeStr);
          final parsedEnd = _mergeDateWithTime(localStart, endTimeStr);
          if (parsedStart != null && parsedEnd != null) {
            startTime = parsedStart;
            endTime = parsedEnd;
          } else {
            endTime =
                localStart.add(Duration(minutes: (durationHours * 60).round()));
          }
        } else {
          endTime =
              localStart.add(Duration(minutes: (durationHours * 60).round()));
        }

        final learnerName = _readLearnerName(lesson);

        final dayKey = _normalizeDate(localStart);
        map.putIfAbsent(dayKey, () => <_LessonSlot>[]).add(
              _LessonSlot(
                start: startTime,
                end: endTime,
                learner: learnerName,
                focus: (lesson['focus'] ?? 'Driving lesson').toString(),
              ),
            );
      }

      map.forEach((key, value) {
        value.sort((a, b) => a.start.compareTo(b.start));
      });

      if (!mounted) return;
      setState(() {
        _slotsByDay
          ..clear()
          ..addAll(map);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  static DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _startOfWeek(DateTime date) =>
      date.subtract(Duration(days: date.weekday % 7));

  static DateTime? _mergeDateWithTime(DateTime date, String time) {
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  List<_LessonSlot> _slotsForDay(DateTime date) {
    final key = _normalizeDate(date);
    final slots = _slotsByDay[key];
    return slots != null ? List<_LessonSlot>.from(slots) : <_LessonSlot>[];
  }

  Widget _emptyLessonsPlaceholder({
    required String title,
    required String subtitle,
    IconData icon = Icons.event_busy,
  }) {
    return GlassPanel(
      borderRadius: BorderRadius.circular(26),
      opacity: 0.42,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: AppColors.primaryBlue),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 17,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildDayView() {
    final today = _normalizeDate(DateTime.now());
    final slots = _slotsForDay(today);
    final summaryText = slots.isEmpty
        ? 'No lessons scheduled'
        : '${slots.length} ${slots.length == 1 ? 'lesson' : 'lessons'} scheduled';

    return RefreshIndicator(
      color: AppColors.primaryBlue,
      onRefresh: _loadLessons,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          GlassPanel(
            borderRadius: BorderRadius.circular(28),
            opacity: 0.42,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat.yMMMMEEEEd().format(today),
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  summaryText,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (slots.isEmpty)
            _emptyLessonsPlaceholder(
              title: 'No lessons scheduled today.',
              subtitle:
                  'Accept learner requests or add lessons to fill your schedule.',
            )
          else
            ...slots.map(_buildLessonTile),
        ],
      ),
    );
  }

  Widget _buildWeekView() {
    final start = _startOfWeek(DateTime.now());
    final days = List<DateTime>.generate(
      7,
      (index) => start.add(Duration(days: index)),
    );

    return RefreshIndicator(
      color: AppColors.primaryBlue,
      onRefresh: _loadLessons,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          GlassPanel(
            borderRadius: BorderRadius.circular(28),
            opacity: 0.42,
            padding: const EdgeInsets.all(20),
            child: const Text(
              'This week',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: days.map((day) {
                final slots = _slotsForDay(day);
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 200,
                    child: GlassPanel(
                      borderRadius: BorderRadius.circular(26),
                      opacity: 0.42,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat.E().add_MMMd().format(day),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (slots.isEmpty)
                            const Text(
                              'No lessons',
                              style: TextStyle(color: Colors.black54),
                            )
                          else
                            ...slots.map(_buildLessonChip),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthView() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final firstWeekday = firstDay.weekday % 7;
    final daysInMonth =
        DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final totalCells = ((firstWeekday + daysInMonth) / 7).ceil() * 7;

    return RefreshIndicator(
      color: AppColors.primaryBlue,
      onRefresh: _loadLessons,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: GlassPanel(
              borderRadius: BorderRadius.circular(28),
              opacity: 0.42,
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Month',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _currentMonth = DateTime(
                                _currentMonth.year, _currentMonth.month - 1, 1);
                          });
                          _loadLessons();
                        },
                        icon: const Icon(Icons.chevron_left),
                        color: AppColors.primaryBlue,
                      ),
                      Text(
                        DateFormat.yMMMM().format(_currentMonth),
                        style: const TextStyle(color: Colors.black54),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _currentMonth = DateTime(
                                _currentMonth.year, _currentMonth.month + 1, 1);
                          });
                          _loadLessons();
                        },
                        icon: const Icon(Icons.chevron_right),
                        color: AppColors.primaryBlue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: GlassPanel(
              borderRadius: BorderRadius.circular(32),
              opacity: 0.42,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: totalCells,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.65,
                ),
                itemBuilder: (context, index) {
                  final dayNumber = index - firstWeekday + 1;
                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return const SizedBox.shrink();
                  }
                  final date = DateTime(
                      _currentMonth.year, _currentMonth.month, dayNumber);
                  final slots = _slotsForDay(date);
                  final hasLessons = slots.isNotEmpty;
                  return _MonthDayCell(
                    dayNumber: dayNumber,
                    slots: slots,
                    highlighted: hasLessons,
                    onTap: hasLessons
                        ? () => _showDaySummary(context, date, slots)
                        : null,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonTile(_LessonSlot slot) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
        borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  slot.timeLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
                Text(
                  slot.learner,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              slot.focus,
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonChip(_LessonSlot slot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            slot.timeLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            slot.learner,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double tabBarHeight = 64;
    final mediaPadding = MediaQuery.of(context).padding;
    final contentTopInset = mediaPadding.top + kToolbarHeight + tabBarHeight;
    final contentBottomInset = mediaPadding.bottom + 16;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Bookings'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: widget.reduceMotion
                ? 'Enable animated background'
                : 'Reduce motion (static background)',
            onPressed: widget.onToggleMotion,
            icon: Icon(
              widget.reduceMotion
                  ? Icons.visibility
                  : Icons.visibility_off_outlined,
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(tabBarHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: GlassPanel(
              borderRadius: BorderRadius.circular(999),
              opacity: 0.48,
              padding: const EdgeInsets.all(6),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                labelColor: AppColors.primaryBlue,
                unselectedLabelColor: Colors.black54,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: 'Today'),
                  Tab(text: 'This Week'),
                  Tab(text: 'This Month'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          widget.reduceMotion
              ? Container(color: Colors.white)
              : AnimatedContainer(
                  duration: const Duration(milliseconds: 1200),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE0F2FF),
                        Color(0xFFF6F3FF),
                        Color(0xFFE7F2FF),
                      ],
                    ),
                  ),
                ),
          if (!widget.reduceMotion) ...[
            AnimatedPositioned(
              duration: const Duration(milliseconds: 1800),
              top: _bgShift ? 40 : 120,
              left: _bgShift ? -30 : 40,
              child: const _BlurCircle(
                diameter: 200,
                color: Color(0xFFBCE7FF),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 1800),
              bottom: _bgShift ? 20 : 120,
              right: _bgShift ? -50 : 20,
              child: const _BlurCircle(
                diameter: 260,
                color: Color(0xFFCEC4FF),
              ),
            ),
          ],
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                0,
                contentTopInset,
                0,
                contentBottomInset,
              ),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error
                      ? _BookingsErrorView(onRetry: _loadLessons)
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildDayView(),
                            _buildWeekView(),
                            _buildMonthView(),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDaySummary(
    BuildContext context,
    DateTime date,
    List<_LessonSlot> slots,
  ) {
    if (slots.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.yMMMMEEEEd().format(date),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 12),
                ...slots.map(
                  (slot) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildLessonTile(slot),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.dayNumber,
    required this.slots,
    required this.highlighted,
    this.onTap,
  });

  final int dayNumber;
  final List<_LessonSlot> slots;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasLessons = highlighted && slots.isNotEmpty;
    final Color backgroundColor =
        hasLessons ? Colors.white : Colors.white.withOpacity(0.85);
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          dayNumber.toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: hasLessons ? AppColors.primaryBlue : Colors.black87,
          ),
        ),
        if (hasLessons)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${slots.length} lesson${slots.length == 1 ? '' : 's'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontSize: 11,
                height: 1.1,
              ),
            ),
          ),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(hasLessons ? 0.08 : 0.03),
                blurRadius: hasLessons ? 14 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: content,
        ),
      ),
    );
  }
}

class _LessonSlot {
  _LessonSlot({
    required this.start,
    required this.end,
    required this.learner,
    required this.focus,
  });

  final DateTime start;
  final DateTime end;
  final String learner;
  final String focus;

  String get timeLabel =>
      '${DateFormat('h:mm a').format(start)} \u2013 ${DateFormat('h:mm a').format(end)}';
}

class _StudentsTab extends StatefulWidget {
  const _StudentsTab({
    super.key,
    required this.reduceMotion,
    required this.onToggleMotion,
  });

  final bool reduceMotion;
  final VoidCallback onToggleMotion;

  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  late final Timer _bgTimer;
  bool _bgShift = false;

  @override
  void initState() {
    super.initState();
    _bgTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        setState(() => _bgShift = !_bgShift);
      }
    });
  }

  @override
  void dispose() {
    _bgTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Learners'),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: widget.reduceMotion
                ? 'Enable animated background'
                : 'Reduce motion (static background)',
            onPressed: widget.onToggleMotion,
            icon: Icon(
              widget.reduceMotion
                  ? Icons.visibility
                  : Icons.visibility_off_outlined,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          widget.reduceMotion
              ? Container(color: Colors.white)
              : AnimatedContainer(
                  duration: const Duration(milliseconds: 1200),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE0F2FF),
                        Color(0xFFF6F3FF),
                        Color(0xFFE7F2FF),
                      ],
                    ),
                  ),
                ),
          if (!widget.reduceMotion) ...[
            AnimatedPositioned(
              duration: const Duration(milliseconds: 1800),
              top: _bgShift ? 50 : 130,
              left: _bgShift ? -40 : 30,
              child: const _BlurCircle(
                diameter: 220,
                color: Color(0xFFBCE7FF),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 1800),
              bottom: _bgShift ? 30 : 110,
              right: _bgShift ? -30 : 20,
              child: const _BlurCircle(
                diameter: 260,
                color: Color(0xFFCEC4FF),
              ),
            ),
          ],
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: const LearnerRosterView(
                  padding: EdgeInsets.fromLTRB(0, 0, 0, 32),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? primaryActionText;
  final VoidCallback? onPrimaryAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
    this.primaryActionText,
    this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: AppColors.primaryBlue),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            if (primaryActionText != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onPrimaryAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                ),
                child: Text(primaryActionText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String name;
  final String scheduleSummary;
  final int totalClasses;

  const _WelcomeCard({
    required this.name,
    required this.scheduleSummary,
    required this.totalClasses,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedName = name.trim();
    final firstName = normalizedName.isEmpty
        ? 'there'
        : normalizedName.split(RegExp(r'\s+')).first;

    return GlassPanel(
      padding: const EdgeInsets.all(24),
      borderRadius: BorderRadius.circular(26),
      tintColor: Colors.white,
      opacity: 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hey $firstName',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Today's Schedule",
            style: TextStyle(
              color: AppColors.primaryBlue.withOpacity(0.7),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.55)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white.withOpacity(0.5),
                  ),
                  child: const Icon(
                    Icons.schedule_outlined,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    scheduleSummary,
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (totalClasses > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$totalClasses lessons delivered overall',
              style: TextStyle(
                color: AppColors.primaryBlue.withOpacity(0.65),
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<_StatMetric> metrics;

  const _StatsRow({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 2;
        const spacing = 12.0;
        const cardHeight = 110.0;
        final size = MediaQuery.of(context).size;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : size.width;
        final availableWidth = math.max(maxWidth, 0.0);
        final totalSpacing = spacing * (columns - 1);
        final cardWidth =
            math.max((availableWidth - totalSpacing) / columns, 0.0);
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: cardWidth,
                  child: SizedBox(
                    height: cardHeight,
                    child: _StatItem(metric: metric),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StatMetric {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _StatItem extends StatelessWidget {
  final _StatMetric metric;

  const _StatItem({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: metric.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(metric.icon, color: metric.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  metric.value,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  metric.label,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 15,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  const _BlurCircle({
    required this.diameter,
    required this.color,
  });

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.35),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }
}

class _UpcomingLessonsCard extends StatelessWidget {
  final List<Map<String, dynamic>> lessons;
  final void Function(Map<String, dynamic> lesson) onLessonSelected;

  final VoidCallback onViewAll;

  const _UpcomingLessonsCard({
    required this.lessons,
    required this.onLessonSelected,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Today's Lessons",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (lessons.isEmpty)
            const Text('No lessons scheduled for today.')
          else
              ...lessons.map(
              (lesson) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ScheduleCard(
                  learner: _lessonLearnerName(lesson),
                  time: _lessonTimeLabel(lesson),
                  focus: _lessonFocusLabel(lesson),
                  location: _lessonPickupLabel(lesson),
                  avatarUrl: _lessonAvatarUrl(lesson),
                  onTap: () => onLessonSelected(lesson),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _lessonLearnerName(Map<String, dynamic> lesson) {
    final learner = lesson['learner'];
    if (learner is Map<String, dynamic>) {
      final direct = (learner['name'] as String?)?.trim();
      if (direct != null && direct.isNotEmpty) return direct;
      final first = (learner['first_name'] ?? '').toString().trim();
      final last = (learner['last_name'] ?? '').toString().trim();
      final name = '$first $last'.trim();
      if (name.isNotEmpty) return name;
      final email = (learner['email'] ?? '').toString().trim();
      if (email.isNotEmpty) return email;
    }
    final rawName = lesson['learner_name'];
    if (rawName is String && rawName.trim().isNotEmpty) {
      return rawName.trim();
    }
    return 'Learner';
  }

  static String _lessonTimeLabel(Map<String, dynamic> lesson) {
    final scheduled = lesson['scheduled_at'] as String?;
    DateTime? baseDate =
        scheduled != null ? DateTime.tryParse(scheduled)?.toLocal() : null;
    final now = DateTime.now();
    final isToday = baseDate != null &&
        baseDate.year == now.year &&
        baseDate.month == now.month &&
        baseDate.day == now.day;

    DateTime? merge(DateTime date, String? raw) {
      if (raw == null || raw.isEmpty) return null;
      final parts = raw.split(':');
      if (parts.length < 2) return null;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return null;
      return DateTime(date.year, date.month, date.day, hour, minute)
          .toLocal();
    }

    DateTime? start = baseDate;
    DateTime? end;

    if (baseDate != null) {
      final startCandidate = merge(baseDate, lesson['start_time']?.toString());
      if (startCandidate != null) {
        start = startCandidate;
      }
      final endCandidate = merge(baseDate, lesson['end_time']?.toString());
      if (endCandidate != null) {
        end = endCandidate;
      }
    }

    if (start != null && end == null) {
      double durationHours = 1.0;
      final rawDuration = lesson['duration_hours'];
      if (rawDuration is num) {
        durationHours = rawDuration.toDouble();
      } else if (lesson['duration_minutes'] is num) {
        durationHours = (lesson['duration_minutes'] as num).toDouble() / 60.0;
      }
      if (durationHours < 0.25) {
        durationHours = 0.25;
      }
      end = start.add(Duration(minutes: (durationHours * 60).round()));
    }

    final dateLabel = !isToday && baseDate != null
        ? DateFormat.yMMMd().format(baseDate)
        : null;
    if (start != null && end != null && end.isAfter(start)) {
      final timeRange =
          '${DateFormat.jm().format(start)} \u2013 ${DateFormat.jm().format(end)}';
      return dateLabel != null ? '$dateLabel $timeRange' : timeRange;
    }
    if (start != null) {
      final startLabel = DateFormat.jm().format(start);
      return dateLabel != null ? '$dateLabel $startLabel' : startLabel;
    }
    if (baseDate != null) {
      return DateFormat.yMMMd().add_jm().format(baseDate);
    }
    return lesson['time']?.toString() ?? '';
  }

  static String _lessonFocusLabel(Map<String, dynamic> lesson) {
    String pickFocus() {
      final direct = (lesson['focus'] ?? '').toString().trim();
      if (direct.isNotEmpty) return direct;
      final fromLesson = (lesson['learning_focus'] ?? '').toString().trim();
      if (fromLesson.isNotEmpty) return fromLesson;
      if (lesson['learner_profile'] is Map<String, dynamic>) {
        final profile = Map<String, dynamic>.from(
          lesson['learner_profile'] as Map,
        );
        final profileFocus = (profile['learning_focus'] ?? '').toString().trim();
        if (profileFocus.isNotEmpty) return profileFocus;
      }
      if (lesson['learner'] is Map<String, dynamic>) {
        final learner = Map<String, dynamic>.from(lesson['learner'] as Map);
        final learnerFocus = (learner['learning_focus'] ?? '').toString().trim();
        if (learnerFocus.isNotEmpty) return learnerFocus;
      }
      return '';
    }

    final raw = pickFocus();
    if (raw.isEmpty) return 'Driving lesson';
    final lower = raw.toLowerCase();
    if (lower.contains('g2')) return 'G2 Test Prep';
    if (lower == 'g' || lower.contains(' g ') || lower.contains('g test')) {
      return 'G Test Prep';
    }
    if (lower.contains('pr')) return 'PR Lesson';
    return raw;
  }

  static String _lessonPickupLabel(Map<String, dynamic> lesson) {
    final raw = (lesson['pickup_location'] ?? '').toString().trim();
    if (raw.isNotEmpty) return raw;

    List<dynamic>? _preferredFrom(Map<String, dynamic>? source) {
      if (source == null) return null;
      final value = source['preferred_locations'];
      return value is List ? value : null;
    }

    final learner = lesson['learner'];
    List<dynamic>? preferredLocations;
    if (learner is Map<String, dynamic>) {
      preferredLocations = _preferredFrom(learner) ??
          _preferredFrom(
            learner['profile'] is Map
                ? Map<String, dynamic>.from(learner['profile'] as Map)
                : null,
          );
    }
    if (preferredLocations == null &&
        lesson['learner_profile'] is Map<String, dynamic>) {
      final profile = Map<String, dynamic>.from(
        lesson['learner_profile'] as Map,
      );
      preferredLocations = _preferredFrom(profile) ??
          _preferredFrom(
            profile['profile'] is Map
                ? Map<String, dynamic>.from(profile['profile'] as Map)
                : null,
          );
    }

    String? preferredSummary(List<dynamic> locations) {
      for (final entry in locations) {
        if (entry is Map) {
          final label = (entry['label'] ?? entry['type'] ?? '')
              .toString()
              .trim();
          final address = (entry['address'] ?? '').toString().trim();
          if (label.isNotEmpty && address.isNotEmpty) {
            return '$label - $address';
          }
          if (address.isNotEmpty) return address;
          if (label.isNotEmpty) return label;
        } else if (entry is String && entry.trim().isNotEmpty) {
          return entry.trim();
        }
      }
      return null;
    }

    final preferred = preferredLocations != null
        ? preferredSummary(preferredLocations)
        : null;
    if (preferred != null && preferred.isNotEmpty) return preferred;

    final city = () {
      if (learner is Map<String, dynamic>) {
        final value = (learner['city'] ?? '').toString().trim();
        if (value.isNotEmpty) return value;
        if (learner['profile'] is Map) {
          final nested = Map<String, dynamic>.from(learner['profile'] as Map);
          final nestedCity = (nested['city'] ?? '').toString().trim();
          if (nestedCity.isNotEmpty) return nestedCity;
        }
      }
      if (lesson['learner_profile'] is Map<String, dynamic>) {
        final profile = Map<String, dynamic>.from(
          lesson['learner_profile'] as Map,
        );
        final cityDirect = (profile['city'] ?? '').toString().trim();
        if (cityDirect.isNotEmpty) return cityDirect;
        if (profile['profile'] is Map) {
          final nested = Map<String, dynamic>.from(profile['profile'] as Map);
          final nestedCity = (nested['city'] ?? '').toString().trim();
          if (nestedCity.isNotEmpty) return nestedCity;
        }
      }
      return '';
    }();
    if (city.isNotEmpty) return city;

    return 'See details';
  }

  static String _lessonAvatarUrl(Map<String, dynamic> lesson) {
    final learner = lesson['learner'];
    if (learner is Map<String, dynamic>) {
      final direct = (learner['profile_image_url'] ?? learner['avatar_url'])
          ?.toString()
          .trim();
      if (direct != null && direct.isNotEmpty) return direct;
      if (learner['profile'] is Map) {
        final nested = Map<String, dynamic>.from(learner['profile'] as Map);
        final nestedUrl =
            (nested['profile_image_url'] ?? nested['avatar_url'])
                ?.toString()
                .trim();
        if (nestedUrl != null && nestedUrl.isNotEmpty) return nestedUrl;
      }
    }
    if (lesson['learner_profile'] is Map<String, dynamic>) {
      final profile = Map<String, dynamic>.from(
        lesson['learner_profile'] as Map,
      );
      final url = (profile['profile_image_url'] ?? profile['avatar_url'])
          ?.toString()
          .trim();
      if (url != null && url.isNotEmpty) return url;
      if (profile['profile'] is Map) {
        final nested = Map<String, dynamic>.from(profile['profile'] as Map);
        final nestedUrl =
            (nested['profile_image_url'] ?? nested['avatar_url'])
                ?.toString()
                .trim();
        if (nestedUrl != null && nestedUrl.isNotEmpty) return nestedUrl;
      }
    }
    return '';
  }
}

class _RequestsCard extends StatelessWidget {
  final List<Map<String, dynamic>> requests;

  const _RequestsCard({required this.requests});

  @override
  Widget build(BuildContext context) {
    final pendingCount = requests.length;
    final hasRequests = pendingCount > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5EB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD9B3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_outlined, color: Color(0xFFFF8A34)),
              SizedBox(width: 8),
              Text(
                'Pending Booking Requests',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pendingCount == 0
                ? 'You have no pending requests.'
                : 'You have $pendingCount new booking request${pendingCount == 1 ? '' : 's'}.',
            style: const TextStyle(color: Colors.black87),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6A2F),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: hasRequests
                  ? () => GoRouter.of(context).push(
                        AppRoutes.reviewLearnerRequest,
                        extra: requests.first,
                      )
                  : null,
              child: Text(
                hasRequests ? 'Review Requests' : 'No Requests',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassBottomNavBar extends StatelessWidget {
  const _GlassBottomNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItemData(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: 'Overview',
    ),
    _NavItemData(
      icon: Icons.event_note_outlined,
      activeIcon: Icons.event_note,
      label: 'Schedule',
    ),
    _NavItemData(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today,
      label: 'Bookings',
    ),
    _NavItemData(
      icon: Icons.school_outlined,
      activeIcon: Icons.school,
      label: 'Learners',
    ),
    _NavItemData(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: GlassPanel(
        borderRadius: BorderRadius.circular(36),
        opacity: 0.46,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final selected = index == currentIndex;
            final isBookings = item.label == 'Bookings';
            final Color accent = AppColors.ocean;
            final Color bgColor = isBookings
                ? (selected ? accent : accent.withOpacity(0.12))
                : (selected ? Colors.white : Colors.transparent);
            final Color iconColor = isBookings
                ? (selected ? Colors.white : accent)
                : (selected ? AppColors.primaryBlue : Colors.black54);
            final Color textColor = isBookings
                ? (selected ? Colors.white : accent)
                : (selected
                    ? AppColors.primaryBlue
                    : Colors.black87.withOpacity(0.6));
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => onTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: isBookings
                                  ? accent.withOpacity(0.28)
                                  : Colors.black.withOpacity(0.08),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected ? item.activeIcon : item.icon,
                        color: iconColor,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 16,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            item.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
