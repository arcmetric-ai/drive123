import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_radii.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_spacing.dart';
import '../../models/lesson_model.dart';
import '../../services/supabase_service.dart';
import '../../widgets/compact_schedule_lesson_card.dart';
import '../../widgets/my_lessons_empty_state.dart';
import '../../widgets/primary_schedule_lesson_card.dart';
import '../../widgets/schedule_day_card.dart';
import '../../widgets/lesson_feedback_sheet.dart';
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
  DateTime? _selectedUpcomingDate;
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
        _selectedUpcomingDate = _resolveSelectedUpcomingDate(
          upcomingLessons: upcoming,
          ongoingLesson: ongoing,
          previousSelection: _selectedUpcomingDate,
        );
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
    final bestOfferingRate = offeringRates.isNotEmpty
        ? offeringRates.reduce((a, b) => a < b ? a : b)
        : 0.0;

    final fallbackRate = bestOfferingRate > 0 ? bestOfferingRate : hourlyRate;
    final computed = fallbackRate > 0 ? fallbackRate * duration : 0.0;
    return computed > 0 ? computed : 0.0;
  }

  String _formatPriceLabel(LessonModel lesson) {
    final price = _resolveLessonPrice(lesson);
    if (price <= 0) return 'Price to be confirmed';

    final needsDecimals = price % 1 != 0;
    final formatted =
        needsDecimals ? price.toStringAsFixed(2) : price.toStringAsFixed(0);
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
    _tabController.addListener(_handleTabChanged);
    _loadLessons();
  }

  void _handleTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: _buildHeader(),
            ),
            TabBar(
              controller: _tabController,
              labelPadding: const EdgeInsets.only(bottom: 10),
              indicatorSize: TabBarIndicatorSize.label,
              indicatorColor: AppColors.primary,
              indicatorWeight: 4,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.mutedForeground,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'Upcoming'),
                Tab(text: 'Completed'),
                Tab(text: 'Cancelled'),
              ],
            ),
            const Divider(height: 1, thickness: 1, color: AppColors.foreground),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUpcomingLessons(),
                  _buildCompletedLessons(),
                  _buildCancelledLessons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final hasSchedule = _tabController.index == 0 &&
        (_upcomingLessons.isNotEmpty || _ongoingLesson != null);

    if (!hasSchedule) {
      return const Center(
        child: Text(
          'My Lessons',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.foreground,
          ),
        ),
      );
    }

    return Row(
      children: [
        const Expanded(
          child: Text(
            'Your Schedule',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
        ),
        Container(
          width: 78,
          height: 78,
          decoration: const BoxDecoration(
            color: AppColors.secondary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            onPressed: _openCalendarPicker,
            icon: const Icon(
              Icons.calendar_month_rounded,
              size: 34,
              color: AppColors.foreground,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openCalendarPicker() async {
    final dates = _scheduleDates;
    if (dates.isEmpty) return;

    final first = dates.first;
    final last = dates.last;
    final initial = _selectedUpcomingDate ?? first;
    final picked = await showDatePicker(
      context: context,
      initialDate:
          initial.isBefore(first) || initial.isAfter(last) ? first : initial,
      firstDate: first,
      lastDate: last,
      selectableDayPredicate: (day) =>
          dates.any((scheduled) => _isSameDay(scheduled, day)),
      helpText: 'Select a lesson date',
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: AppColors.primaryForeground,
              secondary: AppColors.accent,
              onSecondary: AppColors.accentForeground,
              surface: AppColors.card,
              onSurface: AppColors.foreground,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: AppColors.card,
              surfaceTintColor: Colors.transparent,
              elevation: 18,
              shadowColor: AppColors.primary.withValues(alpha: 0.18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              headerBackgroundColor: AppColors.primary,
              headerForegroundColor: AppColors.primaryForeground,
              dividerColor: Colors.transparent,
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primaryForeground;
                }
                if (states.contains(WidgetState.disabled)) {
                  return AppColors.grey300;
                }
                return AppColors.foreground;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.primary;
                }
                return Colors.transparent;
              }),
              todayForegroundColor: const WidgetStatePropertyAll(
                AppColors.foreground,
              ),
              todayBorder: const BorderSide(
                color: AppColors.accent,
                width: 2,
              ),
              weekdayStyle: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
              dayStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
              yearStyle: const TextStyle(letterSpacing: 0),
              headerHeadlineStyle: const TextStyle(
                color: AppColors.primaryForeground,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
              headerHelpStyle: TextStyle(
                color: AppColors.primaryForeground.withValues(alpha: 0.82),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: AppColors.mutedForeground,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
          child: child,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedUpcomingDate = _dateOnly(picked));
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
      return _buildStartLearningView();
    }

    final scheduleDates = _scheduleDates;
    final selectedDate = _selectedUpcomingDate ?? scheduleDates.first;
    final selectedLessons = _lessonsForDate(selectedDate);
    final primaryLesson = selectedLessons.isNotEmpty
        ? selectedLessons.first
        : (_ongoingLesson ?? _upcomingLessons.first);
    final remainingSelectedLessons = selectedLessons.skip(1).toList();
    final nextDate = _nextScheduleDate(selectedDate);
    final nextDateLessons =
        nextDate == null ? const <LessonModel>[] : _lessonsForDate(nextDate);

    return RefreshIndicator(
      onRefresh: _refreshLessons,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: scheduleDates.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) {
                final day = scheduleDates[index];
                return ScheduleDayCard(
                  monthLabel: DateFormat('MMM').format(day),
                  dayLabel: DateFormat('d').format(day),
                  weekdayLabel: DateFormat('EEE').format(day),
                  isSelected: _isSameDay(day, selectedDate),
                  hasLesson: _lessonsForDate(day).isNotEmpty,
                  onTap: () => setState(() => _selectedUpcomingDate = day),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildScheduleSectionHeader(
            title: _isToday(selectedDate)
                ? 'Today\'s Lessons'
                : DateFormat('EEEE, MMM d').format(selectedDate),
            dotColor: AppColors.accent,
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryScheduleLessonCard(
            avatarUrl: primaryLesson.instructor.user.profileImageUrl,
            fallbackInitials: _initialsForLesson(primaryLesson),
            instructorName: _instructorName(primaryLesson),
            subtitle: _lessonSubtitle(primaryLesson),
            focusLabel: _lessonFocusLabel(primaryLesson),
            timeLabel: _lessonTimeLabel(primaryLesson, includeDuration: true),
            locationLabel: primaryLesson.location ?? 'Location to be confirmed',
            primaryLabel:
                primaryLesson.isInProgress ? 'LIVE LESSON' : 'VIEW LESSON',
            onPrimaryPressed: () => _openLessonDetails(primaryLesson),
            onCallPressed: _callActionForLesson(primaryLesson),
          ),
          if (remainingSelectedLessons.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            for (final lesson in remainingSelectedLessons) ...[
              CompactScheduleLessonCard(
                avatarUrl: lesson.instructor.user.profileImageUrl,
                fallbackInitials: _initialsForLesson(lesson),
                instructorName: _instructorName(lesson),
                subtitle: _lessonSubtitle(lesson),
                focusLabel: _lessonFocusLabel(lesson),
                dateTimeLabel: _lessonDateTimeLabel(lesson),
                actionLabel: 'View',
                onActionPressed: () => _openLessonDetails(lesson),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
          if (nextDateLessons.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildScheduleSectionHeader(
              title: _upcomingSectionLabel(nextDate!),
              dotColor: AppColors.grey300,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final lesson in nextDateLessons) ...[
              CompactScheduleLessonCard(
                avatarUrl: lesson.instructor.user.profileImageUrl,
                fallbackInitials: _initialsForLesson(lesson),
                instructorName: _instructorName(lesson),
                subtitle: _lessonSubtitle(lesson),
                focusLabel: _lessonFocusLabel(lesson),
                dateTimeLabel: _lessonDateTimeLabel(lesson),
                actionLabel: 'View',
                onActionPressed: () => _openLessonDetails(lesson),
                isMuted: true,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildScheduleSectionHeader({
    required String title,
    required Color dotColor,
  }) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
        ),
      ],
    );
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _isSameDay(DateTime a, DateTime b) => _dateOnly(a) == _dateOnly(b);

  bool _isToday(DateTime value) => _isSameDay(value, DateTime.now());

  DateTime? _resolveSelectedUpcomingDate({
    required List<LessonModel> upcomingLessons,
    required LessonModel? ongoingLesson,
    required DateTime? previousSelection,
  }) {
    final dates = <DateTime>{
      if (ongoingLesson != null)
        _dateOnly(ongoingLesson.scheduledDate.toLocal()),
      ...upcomingLessons
          .map((lesson) => _dateOnly(lesson.scheduledDate.toLocal())),
    }.toList()
      ..sort();

    if (dates.isEmpty) return null;
    if (previousSelection != null) {
      for (final date in dates) {
        if (_isSameDay(date, previousSelection)) {
          return date;
        }
      }
    }
    for (final date in dates) {
      if (_isToday(date)) return date;
    }
    return dates.first;
  }

  List<DateTime> get _scheduleDates => <DateTime>{
        if (_ongoingLesson != null)
          _dateOnly(_ongoingLesson!.scheduledDate.toLocal()),
        ..._upcomingLessons
            .map((lesson) => _dateOnly(lesson.scheduledDate.toLocal())),
      }.toList()
        ..sort();

  List<LessonModel> _lessonsForDate(DateTime date) {
    final lessons = <LessonModel>[
      if (_ongoingLesson != null &&
          _isSameDay(_ongoingLesson!.scheduledDate.toLocal(), date))
        _ongoingLesson!,
      ..._upcomingLessons.where(
        (lesson) => _isSameDay(lesson.scheduledDate.toLocal(), date),
      ),
    ];
    lessons.sort(
        (a, b) => _lessonStartDateTime(a).compareTo(_lessonStartDateTime(b)));
    return lessons;
  }

  DateTime? _nextScheduleDate(DateTime currentDate) {
    for (final date in _scheduleDates) {
      if (date.isAfter(_dateOnly(currentDate))) {
        return date;
      }
    }
    return null;
  }

  String _instructorName(LessonModel lesson) =>
      '${lesson.instructor.user.firstName} ${lesson.instructor.user.lastName}'
          .trim();

  String _initialsForLesson(LessonModel lesson) {
    final first = lesson.instructor.user.firstName;
    final last = lesson.instructor.user.lastName;
    final buffer = StringBuffer();
    if (first.isNotEmpty) buffer.write(first[0]);
    if (last.isNotEmpty) buffer.write(last[0]);
    return buffer.isEmpty ? 'DT' : buffer.toString().toUpperCase();
  }

  String _lessonSubtitle(LessonModel lesson) {
    final transmission = (lesson.instructor.vehicles.isNotEmpty
                ? lesson.instructor.vehicles.first.transmission
                : lesson.instructor.transmissionTypes.isNotEmpty
                    ? lesson.instructor.transmissionTypes.first
                    : null)
            ?.trim()
            .toUpperCase() ??
        'AUTO';
    final vehicle = lesson.instructor.vehicles.isNotEmpty
        ? [
            lesson.instructor.vehicles.first.make,
            lesson.instructor.vehicles.first.model,
          ]
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .join(' ')
        : lesson.instructor.carTypes.isNotEmpty
            ? lesson.instructor.carTypes.first
            : 'Vehicle';
    return '$transmission • ${vehicle.toUpperCase()}';
  }

  String? _lessonFocusLabel(LessonModel lesson) {
    final focus = (lesson.focus?.trim().isNotEmpty == true
            ? lesson.focus!.trim()
            : null) ??
        (lesson.instructor.offerings.isNotEmpty
            ? lesson.instructor.offerings.first
            : null);
    if (focus == null || focus.isEmpty) return null;
    final normalized = focus.toLowerCase();
    if (normalized.contains('g2')) return 'G2 PREP';
    if (normalized == 'g' || normalized.contains('g prep')) return 'G PREP';
    if (normalized.contains('refresh') || normalized == 'pr') {
      return 'REFRESHER';
    }
    return focus.toUpperCase();
  }

  String _lessonTimeLabel(
    LessonModel lesson, {
    bool includeDuration = false,
  }) {
    final start = _formatClockLabel(lesson.startTime);
    final end = _formatClockLabel(lesson.endTime);
    if (!includeDuration) return '$start - $end';
    final durationMinutes = (lesson.duration * 60).round();
    return '$start - $end ($durationMinutes mins)';
  }

  String _lessonDateTimeLabel(LessonModel lesson) {
    final dateLabel = DateFormat('MMM d')
        .format(lesson.scheduledDate.toLocal())
        .toUpperCase();
    final timeLabel = _formatClockLabel(lesson.startTime);
    return '$dateLabel, $timeLabel';
  }

  String _formatClockLabel(String raw) {
    final formats = <DateFormat>[
      DateFormat('h:mm a'),
      DateFormat('hh:mm a'),
      DateFormat('H:mm'),
      DateFormat('HH:mm'),
      DateFormat('HH:mm:ss'),
    ];
    for (final format in formats) {
      try {
        return DateFormat('h:mm a').format(format.parse(raw.trim()));
      } catch (_) {}
    }
    return raw.trim().toUpperCase();
  }

  String _upcomingSectionLabel(DateTime date) {
    final tomorrow = _dateOnly(DateTime.now().add(const Duration(days: 1)));
    if (_isSameDay(date, tomorrow)) {
      return 'Upcoming (Tomorrow)';
    }
    return 'Upcoming (${DateFormat('EEE, MMM d').format(date)})';
  }

  VoidCallback? _callActionForLesson(LessonModel lesson) {
    final phone = lesson.instructor.user.phone?.trim();
    if (phone == null || phone.isEmpty) return null;
    return () async {
      final uri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calling is not available on this device right now.'),
          ),
        );
      }
    };
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
        chipColor = AppColors.ocean.withValues(alpha: 0.1);
        textColor = AppColors.ocean;
        label = 'Upcoming';
        break;
      case LessonStatus.inProgress:
        chipColor = AppColors.golden.withValues(alpha: 0.15);
        textColor = AppColors.golden;
        label = 'In Progress';
        break;
      case LessonStatus.completed:
        chipColor = AppColors.success.withValues(alpha: 0.12);
        textColor = AppColors.success;
        label = 'Completed';
        break;
      case LessonStatus.cancelled:
        chipColor = AppColors.error.withValues(alpha: 0.12);
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
                  backgroundColor: AppColors.ocean.withValues(alpha: 0.1),
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
                    color: priceValue > 0 ? AppColors.ocean : Colors.grey[700],
                  ),
                ),
              ],
            ),

            if (lesson.notes != null && lesson.notes!.isNotEmpty) ...[
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

            if (statusLabel == LessonStatus.completed) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => showLessonFeedbackSheet(
                        context,
                        lessonId: lesson.id,
                        revieweeId: lesson.instructor.id,
                        reviewerRole: 'learner',
                        revieweeName:
                            '${lesson.instructor.user.firstName} ${lesson.instructor.user.lastName}',
                      ),
                      icon: const Icon(Icons.star_outline_rounded),
                      label: const Text('Rate lesson'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.outlined(
                    tooltip: 'Report instructor',
                    onPressed: () => showUserReportSheet(
                      context,
                      reportedUserId: lesson.instructor.id,
                      reportedUserName:
                          '${lesson.instructor.user.firstName} ${lesson.instructor.user.lastName}',
                      lessonId: lesson.id,
                    ),
                    icon: const Icon(Icons.flag_outlined),
                  ),
                ],
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
                          : () => _openLessonDetails(lesson),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ocean,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('View'),
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

    if (!mounted) return;
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

  Future<void> _openLessonDetails(LessonModel lesson) async {
    await Navigator.of(context).push<LessonModel?>(
      MaterialPageRoute(
        builder: (context) => OngoingLessonScreen(
          lesson: lesson,
        ),
      ),
    );
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
      _selectedUpcomingDate = _resolveSelectedUpcomingDate(
        upcomingLessons: _upcomingLessons,
        ongoingLesson: _ongoingLesson,
        previousSelection: _selectedUpcomingDate,
      );
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
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xxxl,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.wifi_off_outlined,
                  size: 76,
                  color: AppColors.mutedForeground.withValues(alpha: 0.45),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Something went wrong',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error ?? 'Unable to load your lessons right now.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _refreshLessons,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.primaryForeground,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                      ),
                    ),
                    child: const Text('Try again'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartLearningView({
    String title = 'Start learning',
    String subtitle =
        'You don\'t have any lessons yet. Once your instructor shares a weekly plan, it will appear here.',
  }) {
    return RefreshIndicator(
      onRefresh: _refreshLessons,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.xxl,
        ),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.58,
            child: MyLessonsEmptyState(
              title: title,
              subtitle: subtitle,
              actionLabel: 'Find Instructor',
              onAction: () => context.go(AppRoutes.findInstructor),
            ),
          ),
        ],
      ),
    );
  }
}
