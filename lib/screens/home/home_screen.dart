import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../models/lesson_model.dart';
import '../../models/location_preference.dart';
import '../../models/user_model.dart';
import '../../services/supabase_service.dart';
import '../../widgets/learner_action_tile.dart';
import '../../widgets/learner_bottom_nav_bar.dart';
import '../../widgets/lesson_spotlight_card.dart';
import '../../widgets/verified_profile_badge.dart';
import '../instructor/find_instructor_screen.dart';
import '../lessons/my_lessons_screen.dart';
import '../progress/progress_tracker_screen.dart';
import '../profile/profile_screen.dart';

enum LearnerNotificationType {
  requestAccepted,
  slotBooking,
  lessonReminder,
  lessonStarted,
  lessonEnded,
  ratePrompt,
}

class LearnerNotification {
  const LearnerNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
  });

  final String id;
  final LearnerNotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;

  bool get isRecent => DateTime.now().difference(timestamp).inHours <= 24;
}

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
  String? _profileImageUrl;
  bool _isVerified = false;
  bool _lessonsLoading = true;
  String? _lessonsError;
  LessonModel? _ongoingLesson;
  List<LessonModel> _upcomingLessons = [];
  int _completedSkills = 0;
  bool _isProgressLoading = false;
  String? _nextSkillName;
  List<PreferredLocation> _savedLocations = [];
  String? _selectedLocationKey;
  List<LearnerNotification> _notifications = [];
  String? _notificationsError;
  DateTime? _notificationsLastViewedAt;
  bool _hasUnreadNotifications = false;

  static const _notificationsViewedKey = 'drive_t_notifications_viewed_v1';

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
    _loadStoredLocationPreference();
    _loadProfileSummary();
    _loadProgressSummary();
    _loadUpcomingLessons();
    _initNotifications();
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
      _loadUpcomingLessons(showLoader: false);
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
  bool get _hasRecentNotifications => _hasUnreadNotifications;

  Future<void> _handleSelectLocation() async {
    final result = await GoRouter.of(context).push<LocationSelectionResult>(
      AppRoutes.locationSetup,
      extra: LocationSetupArgs(
        savedLocations: _savedLocations,
        initialSelectionKey: _selectedLocationKey,
        initialManualAddress:
            _selectedLocationKey == null ? _selectedLocation : null,
      ),
    );
    if (result == null) return;

    if (result.isManual) {
      await LocationPreferenceStorage.clear();
      setState(() {
        _selectedLocation = result.displayText;
        _selectedLocationKey = null;
      });
    } else {
      final selected = result.location!;
      await LocationPreferenceStorage.save(selected);
      setState(() {
        _selectedLocation = selected.displayText;
        _selectedLocationKey = selected.storageKey;
      });
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
      _loadUpcomingLessons(showLoader: false);
      _loadNotifications(showLoader: false);
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
      final learnerDetail = await SupabaseService.getLearnerProfileDetail(
        userId,
      );
      if (!mounted) return;
      final parsedLocations = <PreferredLocation>[];
      final rawLocations = learnerDetail?['preferred_locations'];
      if (rawLocations is List) {
        for (final entry in rawLocations) {
          if (entry is Map) {
            final location = PreferredLocation.fromMap(entry);
            if (location.displayText.trim().isNotEmpty) {
              parsedLocations.add(location);
            }
          }
        }
      }

      setState(() {
        if (profile != null) {
          _profileFirstName = profile.firstName;
          _profileImageUrl = profile.profileImageUrl;
          _isVerified = profile.isVerified;
        } else {
          _profileImageUrl = null;
          _isVerified = false;
        }
        final focus = learnerDetail?['learning_focus'] as String?;
        if (focus != null && focus.isNotEmpty) {
          _selectedFocus = focus;
        }
        _savedLocations = parsedLocations;
        if (_selectedLocationKey != null) {
          final matched = _findLocationByKey(
            parsedLocations,
            _selectedLocationKey!,
          );
          if (matched != null) {
            _selectedLocation = matched.displayText;
          }
        } else if (_selectedLocation == null &&
            widget.initialLocation == null &&
            parsedLocations.isNotEmpty) {
          _selectedLocation = parsedLocations.first.displayText;
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

  Future<void> _loadUpcomingLessons({bool showLoader = true}) async {
    final learnerId = SupabaseService.currentUser?.id;
    if (learnerId == null) {
      if (!mounted) return;
      setState(() {
        _lessonsLoading = false;
        _lessonsError = null;
        _ongoingLesson = null;
        _upcomingLessons = [];
      });
      return;
    }

    if (showLoader) {
      setState(() {
        _lessonsLoading = true;
        _lessonsError = null;
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
      LessonModel? ongoing;
      final upcoming = <LessonModel>[];

      for (final lesson in normalizedLessons) {
        switch (lesson.status) {
          case LessonStatus.inProgress:
            ongoing ??= lesson;
            break;
          case LessonStatus.scheduled:
            upcoming.add(lesson);
            break;
          default:
            break;
        }
      }

      upcoming.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

      if (!mounted) return;
      setState(() {
        _ongoingLesson = ongoing;
        _upcomingLessons = upcoming;
        _lessonsLoading = false;
        _lessonsError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lessonsLoading = false;
        _lessonsError = 'Unable to load upcoming lessons right now.';
      });
    }
  }

  Future<void> _loadNotifications({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _notificationsError = null;
      });
    }
    try {
      final notifications = await _fetchNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _hasUnreadNotifications = notifications.any(
          (n) => _isNotificationUnread(n),
        );
        _notificationsError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
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

  Future<void> _initNotifications() async {
    await _loadNotificationsLastViewed();
    await _loadNotifications(showLoader: false);
  }

  Future<void> _markNotificationsViewed() async {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _notificationsLastViewedAt = now;
        _hasUnreadNotifications = false;
      });
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_notificationsViewedKey, now.toIso8601String());
  }

  bool _isNotificationUnread(LearnerNotification notification) {
    final now = DateTime.now();
    final effectiveTimestamp =
        notification.timestamp.isAfter(now) ? now : notification.timestamp;
    if (_notificationsLastViewedAt == null) return true;
    return effectiveTimestamp.isAfter(_notificationsLastViewedAt!);
  }

  Future<List<LearnerNotification>> _fetchNotifications() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      return const [];
    }
    final requests = await SupabaseService.getLessonRequestsForLearner(userId);
    final lessons = await SupabaseService.getLessons(userId);
    return _buildNotificationsFromData(requests, lessons);
  }

  List<LearnerNotification> _buildNotificationsFromData(
    List<Map<String, dynamic>> requests,
    List<LessonModel> lessons,
  ) {
    final now = DateTime.now();
    final Map<String, LearnerNotification> notifications = {};

    for (final request in requests) {
      final status = (request['status'] as String?)?.toLowerCase();
      if (status != 'accepted') continue;
      final timestamp = _parseDateTime(request['updated_at']) ??
          _parseDateTime(request['created_at']) ??
          now;
      if (now.difference(timestamp).inDays > 30) continue;
      final id = 'request-accepted-${request['id']}';
      final instructorName = _resolveInstructorName(request);
      notifications[id] = LearnerNotification(
        id: id,
        type: LearnerNotificationType.requestAccepted,
        title: 'Request accepted',
        message: '$instructorName accepted your lesson request.',
        timestamp: timestamp.toLocal(),
      );
    }

    for (final lesson in lessons) {
      final status = lesson.effectiveStatus;
      final instructorName = _formatInstructorName(lesson.instructor.user);
      final createdAt = lesson.createdAt.toLocal();
      final updatedAt = lesson.updatedAt.toLocal();
      final startDateTime = _combineDateAndTime(
        lesson.scheduledDate,
        lesson.startTime,
      );
      final endDateTime = _combineDateAndTime(
        lesson.scheduledDate,
        lesson.endTime,
      );

      switch (status) {
        case LessonStatus.scheduled:
          if (now.difference(createdAt).inDays <= 30) {
            final slotId = 'lesson-slot-${lesson.id}';
            notifications[slotId] = LearnerNotification(
              id: slotId,
              type: LearnerNotificationType.slotBooking,
              title: 'Lesson booked',
              message:
                  'Your lesson with $instructorName is booked for ${_formatDateTime(startDateTime ?? lesson.scheduledDate)}.',
              timestamp: createdAt,
            );
          }
          if (startDateTime != null &&
              startDateTime.isAfter(now) &&
              startDateTime.difference(now) <= const Duration(hours: 24)) {
            final reminderId = 'lesson-reminder-${lesson.id}';
            final reminderTimestamp = startDateTime.subtract(
              const Duration(hours: 1),
            );
            notifications[reminderId] = LearnerNotification(
              id: reminderId,
              type: LearnerNotificationType.lessonReminder,
              title: 'Lesson reminder',
              message:
                  'Reminder: Lesson with $instructorName on ${_formatDateTime(startDateTime)}.',
              timestamp:
                  reminderTimestamp.isAfter(now) ? reminderTimestamp : now,
            );
          }
          break;
        case LessonStatus.inProgress:
          final startId = 'lesson-started-${lesson.id}';
          final startTimestamp = startDateTime ?? updatedAt;
          notifications[startId] = LearnerNotification(
            id: startId,
            type: LearnerNotificationType.lessonStarted,
            title: 'Lesson started',
            message: 'Lesson with $instructorName has started.',
            timestamp: startTimestamp,
          );
          break;
        case LessonStatus.completed:
          if (now.difference(updatedAt).inDays <= 14) {
            final completedTimestamp = endDateTime ?? updatedAt;
            final endedId = 'lesson-ended-${lesson.id}';
            notifications[endedId] = LearnerNotification(
              id: endedId,
              type: LearnerNotificationType.lessonEnded,
              title: 'Lesson completed',
              message: 'Lesson with $instructorName is complete.',
              timestamp: completedTimestamp,
            );
            final rateId = 'lesson-rate-${lesson.id}';
            notifications[rateId] = LearnerNotification(
              id: rateId,
              type: LearnerNotificationType.ratePrompt,
              title: 'Rate your lesson',
              message: 'Share feedback for your lesson with $instructorName.',
              timestamp: completedTimestamp.add(const Duration(minutes: 5)),
            );
          }
          break;
        case LessonStatus.cancelled:
          break;
      }
    }

    final sorted = notifications.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted;
  }

  String _resolveInstructorName(Map<String, dynamic> request) {
    final profile = request['instructor_profile'];
    if (profile is Map<String, dynamic>) {
      final user = profile['user'];
      if (user is Map<String, dynamic>) {
        final first = (user['first_name'] as String?)?.trim() ?? '';
        final last = (user['last_name'] as String?)?.trim() ?? '';
        final combined = '$first $last'.trim();
        if (combined.isNotEmpty) {
          return combined;
        }
      }
      final displayName = (profile['display_name'] as String?)?.trim();
      if (displayName != null && displayName.isNotEmpty) {
        return displayName;
      }
    }
    return 'Your instructor';
  }

  String _formatInstructorName(UserModel user) {
    final first = user.firstName.trim();
    final last = user.lastName.trim();
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) {
      return combined;
    }
    return 'your instructor';
  }

  DateTime? _combineDateAndTime(DateTime date, String? time) {
    if (time == null || time.isEmpty) return null;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    final seconds = parts.length > 2 ? int.tryParse(parts[2]) : 0;
    if (hours == null || minutes == null) return null;
    return DateTime(
      date.year,
      date.month,
      date.day,
      hours,
      minutes,
      seconds ?? 0,
    );
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  String _formatDateTime(DateTime dateTime) =>
      DateFormat('MMM d, h:mm a').format(dateTime.toLocal());

  Future<void> _handleOpenNotifications() async {
    await _loadNotifications();
    if (!mounted) return;

    var sheetNotifications = List<LearnerNotification>.from(_notifications);
    var sheetError = _notificationsError;
    var sheetLoading = false;

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
                final fetched = await _fetchNotifications();
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

            Future<void> markRead() async {
              await _markNotificationsViewed();
              setModalState(() {});
            }

            return _NotificationsSheet(
              notifications: sheetNotifications,
              isLoading: sheetLoading,
              error: sheetError,
              onRefresh: refresh,
              onMarkRead: markRead,
              isUnread: _isNotificationUnread,
            );
          },
        );
      },
    );

    // Ensure badge clears when the sheet is closed even without tapping Mark read.
    await _markNotificationsViewed();
  }

  Future<void> _refreshUpcomingLessons() =>
      _loadUpcomingLessons(showLoader: false);

  Future<void> _loadStoredLocationPreference() async {
    final stored = await LocationPreferenceStorage.load();
    if (!mounted) return;
    setState(() {
      _selectedLocationKey = stored.key;
      if (stored.display != null && stored.display!.isNotEmpty) {
        _selectedLocation = stored.display;
      }
    });
  }

  PreferredLocation? _findLocationByKey(
    List<PreferredLocation> locations,
    String key,
  ) {
    for (final location in locations) {
      if (location.storageKey == key) {
        return location;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_selectedIndex) {
      0 => HomeDashboard(
          name: _greetingName,
          isLearner: _isLearner,
          profileImageUrl: _profileImageUrl,
          isVerified: _isVerified,
          locationLabel: _selectedLocation,
          selectedFocus: _selectedFocus,
          completedSkills: _completedSkills,
          totalSkills: _totalSkills,
          nextSkillName: _nextSkillName,
          isProgressLoading: _isProgressLoading,
          isLessonsLoading: _lessonsLoading,
          lessonsError: _lessonsError,
          upcomingLessons: _upcomingLessons,
          ongoingLesson: _ongoingLesson,
          onRefreshLessons: _refreshUpcomingLessons,
          onAddLocation: _handleSelectLocation,
          onChangeFocus: _handleChangeFocus,
          onBookLesson: _goToFindInstructor,
          onMyLessons: _goToLessons,
          onProgress: _goToProgress,
          onProfile: _goToProfile,
          onNotifications: _handleOpenNotifications,
          hasNewNotifications: _hasRecentNotifications,
        ),
      1 => FindInstructorScreen(selectedFocus: _selectedFocus),
      2 => const MyLessonsScreen(),
      3 => const ProgressTrackerScreen(),
      4 => const ProfileScreen(),
      _ => const SizedBox.shrink(),
    };

    return Scaffold(
      body: body,
      bottomNavigationBar: LearnerBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          if (index == 1 && _selectedFocus == null && _isLearner) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Select a training focus to see tailored instructors.',
                ),
                backgroundColor: AppColors.info,
              ),
            );
            _handleChangeFocus();
            return;
          }
          _openTab(index);
        },
      ),
    );
  }
}

class HomeDashboard extends StatelessWidget {
  final String name;
  final bool isLearner;
  final String? profileImageUrl;
  final bool isVerified;
  final String? locationLabel;
  final String? selectedFocus;
  final int completedSkills;
  final int totalSkills;
  final String? nextSkillName;
  final bool isProgressLoading;
  final bool isLessonsLoading;
  final String? lessonsError;
  final List<LessonModel> upcomingLessons;
  final LessonModel? ongoingLesson;
  final Future<void> Function()? onRefreshLessons;
  final VoidCallback onAddLocation;
  final VoidCallback onChangeFocus;
  final VoidCallback onBookLesson;
  final VoidCallback onMyLessons;
  final VoidCallback onProgress;
  final VoidCallback onProfile;
  final VoidCallback onNotifications;
  final bool hasNewNotifications;

  const HomeDashboard({
    super.key,
    required this.name,
    required this.isLearner,
    required this.profileImageUrl,
    required this.isVerified,
    required this.locationLabel,
    required this.selectedFocus,
    required this.completedSkills,
    required this.totalSkills,
    required this.nextSkillName,
    required this.isProgressLoading,
    required this.isLessonsLoading,
    required this.lessonsError,
    required this.upcomingLessons,
    required this.ongoingLesson,
    this.onRefreshLessons,
    required this.onAddLocation,
    required this.onChangeFocus,
    required this.onBookLesson,
    required this.onMyLessons,
    required this.onProgress,
    required this.onProfile,
    required this.onNotifications,
    required this.hasNewNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.grey50),
      child: SafeArea(
        child: Column(
          children: [
            _buildGreetingCard(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuickActions(),
                    const SizedBox(height: 30),
                    _buildUpcomingLessons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, $name',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _learnerRoleLine(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onProfile,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: const Color(0xFF5B6BC8),
                  backgroundImage: profileImageUrl != null &&
                          profileImageUrl!.trim().isNotEmpty
                      ? NetworkImage(profileImageUrl!.trim())
                      : null,
                  child: profileImageUrl != null &&
                          profileImageUrl!.trim().isNotEmpty
                      ? null
                      : Text(
                          name.trim().isNotEmpty
                              ? name.trim()[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
                if (isVerified)
                  const Positioned(
                    top: -2,
                    right: -3,
                    child: VerifiedProfileBadge(size: 24),
                  ),
                const Positioned(
                  right: -2,
                  bottom: -2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: Colors.white, width: 3),
                      ),
                    ),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Center(
                        child: Text(
                          'L',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final scheduledCount =
        upcomingLessons.length + (ongoingLesson != null ? 1 : 0);
    final progressPercent = totalSkills <= 0
        ? 0
        : ((completedSkills.clamp(0, totalSkills) / totalSkills) * 100).round();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: LearnerActionTile(
                title: 'Find',
                subtitle: 'Instructors',
                icon: Icons.record_voice_over_rounded,
                onTap: onBookLesson,
                isPrimary: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LearnerActionTile(
                title: 'Schedule',
                subtitle: '$scheduledCount upcoming',
                icon: Icons.calendar_month_rounded,
                onTap: onMyLessons,
                accentColor: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: LearnerActionTile(
                title: 'Progress',
                subtitle: '$progressPercent% to Goal',
                icon: Icons.arrow_outward_rounded,
                onTap: onProgress,
                accentColor: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LearnerActionTile(
                title: 'Theory',
                subtitle: 'Practice tests',
                icon: Icons.menu_book_rounded,
                onTap: onChangeFocus,
                accentColor: AppColors.grey700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpcomingLessons() {
    final header = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Upcoming Lesson',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.foreground,
          ),
        ),
        TextButton(
          onPressed: onMyLessons,
          child: const Text(
            'VIEW ALL',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );

    if (isLessonsLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: const CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
        ],
      );
    }

    if (lessonsError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lessonsError!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      if (onRefreshLessons != null) {
                        onRefreshLessons!();
                      } else {
                        onMyLessons();
                      }
                    },
                    child: Text(
                      onRefreshLessons != null ? 'Try again' : 'Go to Lessons',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final hasLessons = (ongoingLesson != null) || upcomingLessons.isNotEmpty;

    if (!hasLessons) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.border),
            ),
            child: _buildNoLessonsCta(),
          ),
        ],
      );
    }

    final lesson = ongoingLesson ?? upcomingLessons.first;
    final phone = lesson.instructor.user.phone?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        const SizedBox(height: 16),
        LessonSpotlightCard(
          lesson: lesson,
          onDetails: onMyLessons,
          onCall: phone == null || phone.isEmpty
              ? null
              : () async {
                  final uri = Uri(scheme: 'tel', path: phone);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
          note:
              'You will be able to find and request other instructors after your first class.',
        ),
      ],
    );
  }

  String _learnerRoleLine() {
    final focus = selectedFocus?.trim();
    if (focus == 'G2') return 'ONTARIO G2 LEARNER';
    if (focus == 'G') return 'ONTARIO G LEARNER';
    if (focus == 'PR') return 'ONTARIO REFRESHER LEARNER';
    return 'ONTARIO LEARNER';
  }

  Widget _buildNoLessonsCta() {
    final title = isLearner ? 'Start learning' : 'No upcoming lessons';
    final subtitle = isLearner
        ? 'You don\'t have any lessons yet. Book a session to kick off your driving journey.'
        : 'You have no upcoming lessons scheduled. Head to the lessons tab to manage your sessions.';

    final actionButtons = <Widget>[
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isLearner ? onBookLesson : onMyLessons,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.ocean,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(isLearner ? 'Find Instructor' : 'Go to Lessons'),
        ),
      ),
    ];

    if (isLearner) {
      actionButtons.add(const SizedBox(height: 12));
      actionButtons.add(
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onMyLessons,
            child: const Text('View Lessons'),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.school_outlined,
          size: 72,
          color: AppColors.ocean.withOpacity(0.2),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
        ),
        const SizedBox(height: 20),
        ...actionButtons,
      ],
    );
  }
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet({
    required this.notifications,
    required this.isLoading,
    required this.error,
    required this.onRefresh,
    required this.onMarkRead,
    required this.isUnread,
  });

  final List<LearnerNotification> notifications;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;
  final VoidCallback onMarkRead;
  final bool Function(LearnerNotification) isUnread;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + media.viewInsets.bottom,
        ),
        child: SizedBox(
          height: media.size.height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Notifications',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              TextButton(
                onPressed:
                    isLoading || notifications.isEmpty ? null : onMarkRead,
                child: const Text('Mark read'),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildContent(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return _NotificationMessage(
        icon: Icons.error_outline,
        message: error!,
        action: TextButton(
          onPressed: onRefresh,
          child: const Text('Try again'),
        ),
      );
    }
    if (notifications.isEmpty) {
      return const _NotificationMessage(
        icon: Icons.notifications_off_outlined,
        message:
            "No notifications yet.\nWe'll keep you posted when things change.",
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: notifications.length,
        padding: const EdgeInsets.only(bottom: 16),
        separatorBuilder: (_, __) => const Divider(height: 0),
        itemBuilder: (context, index) {
          final notification = notifications[index];
          final theme = Theme.of(context);
          final color = _colorForType(notification.type, theme);
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(_iconForType(notification.type), color: color),
            ),
            title: Text(
              notification.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.message),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM d, h:mm a').format(notification.timestamp),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
            trailing: isUnread(notification)
                ? Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.ocean,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  IconData _iconForType(LearnerNotificationType type) {
    switch (type) {
      case LearnerNotificationType.requestAccepted:
        return Icons.check_circle_outline;
      case LearnerNotificationType.slotBooking:
        return Icons.event_available_outlined;
      case LearnerNotificationType.lessonReminder:
        return Icons.alarm_outlined;
      case LearnerNotificationType.lessonStarted:
        return Icons.play_circle_outline;
      case LearnerNotificationType.lessonEnded:
        return Icons.flag_outlined;
      case LearnerNotificationType.ratePrompt:
        return Icons.star_border;
    }
  }

  Color _colorForType(LearnerNotificationType type, ThemeData theme) {
    switch (type) {
      case LearnerNotificationType.requestAccepted:
        return AppColors.ocean;
      case LearnerNotificationType.slotBooking:
        return AppColors.golden;
      case LearnerNotificationType.lessonReminder:
        return Colors.deepPurpleAccent;
      case LearnerNotificationType.lessonStarted:
        return Colors.green;
      case LearnerNotificationType.lessonEnded:
        return Colors.teal;
      case LearnerNotificationType.ratePrompt:
        return Colors.orangeAccent;
    }
  }
}

class _NotificationMessage extends StatelessWidget {
  const _NotificationMessage({
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.ocean),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
            ),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    );
  }
}
