import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../services/app_notifier.dart';
import '../../services/supabase_service.dart';
import '../../utils/learner_color_utils.dart';

class InstructorAvailabilityScreen extends StatefulWidget {
  const InstructorAvailabilityScreen({super.key});

  @override
  State<InstructorAvailabilityScreen> createState() =>
      _InstructorAvailabilityScreenState();
}

class _InstructorAvailabilityScreenState
    extends State<InstructorAvailabilityScreen> {
  static const int _instructorMonthlyCancelLimit = 6;
  static const List<int> _slotHours = [
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
  ];
  static const Color _scheduledBaseColor = AppColors.primaryBlue;
  static const Color _draftBaseColor = AppColors.golden;
  static const Color _availableBaseColor = AppColors.success;
  static const List<int> _durationOptions = [15, 30, 45, 60];
  static const Map<String, String> _weekdayLabels = {
    'monday': 'Monday',
    'tuesday': 'Tuesday',
    'wednesday': 'Wednesday',
    'thursday': 'Thursday',
    'friday': 'Friday',
    'saturday': 'Saturday',
    'sunday': 'Sunday',
  };

  bool _loading = true;
  bool _sending = false;
  bool _error = false;
  int _weekOffset = 0;
  DateTime _weekStart = _startOfWeek(DateTime.now());

  List<_ScheduledSlot> _committedSlots = [];
  final List<_ScheduledSlot> _draftSlots = [];
  final Map<String, _LearnerOption> _learnerOptions = {};
  Map<String, dynamic>? _instructorProfile;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    AppNotifier.instance.addListener(_handleLessonUpdates);
  }

  @override
  void dispose() {
    AppNotifier.instance.removeListener(_handleLessonUpdates);
    super.dispose();
  }

  void _handleLessonUpdates() {
    _loadWeekSchedule();
  }

  Future<void> _loadInitialData() async {
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
    });

    try {
      final results = await Future.wait([
        SupabaseService.getActiveLearnersWithAvailability(instructorId),
        _fetchLessonsForWeek(_weekStart),
        SupabaseService.getInstructorProfileDetail(instructorId),
      ]);

      final learners = results[0] as List<dynamic>;
      final lessons = results[1] as List<_ScheduledSlot>;
      final instructorProfile = results[2] as Map<String, dynamic>?;

      _learnerOptions
        ..clear()
        ..addEntries(learners
            .whereType<Map<dynamic, dynamic>>()
            .map((raw) => Map<String, dynamic>.from(
                raw.map((key, value) => MapEntry(key.toString(), value))))
            .map((data) => _LearnerOption.fromMap(data))
            .map((option) => MapEntry(option.id, option)));

      setState(() {
        _committedSlots = lessons;
        _draftSlots.clear();
        _instructorProfile = instructorProfile;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _loadWeekSchedule() async {
    final instructorId = SupabaseService.currentUser?.id;
    if (instructorId == null) {
      setState(() {
        _error = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = false;
      _draftSlots.clear();
    });
    try {
      final lessons = await _fetchLessonsForWeek(_weekStart);
      if (!mounted) return;
      setState(() {
        _committedSlots = lessons;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<List<_ScheduledSlot>> _fetchLessonsForWeek(DateTime weekStart) async {
    final instructorId = SupabaseService.currentUser?.id;
    if (instructorId == null) return const [];
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    final rows = await SupabaseService.getInstructorLessonsForRange(
      userId: instructorId,
      start: start,
      end: end,
    );
    return rows
        .map((row) => _ScheduledSlot.fromLessonRow(row))
        .where((slot) => slot != null)
        .cast<_ScheduledSlot>()
        .toList();
  }

  static DateTime _startOfWeek(DateTime date) {
    final day = date.weekday;
    final difference = day - DateTime.monday;
    final monday = date.subtract(Duration(days: difference));
    return DateTime(monday.year, monday.month, monday.day);
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  List<DateTime> _generateSlotsForDay(DateTime day) {
    return _slotHours
        .map((hour) => DateTime(day.year, day.month, day.day, hour))
        .toList();
  }

  _SlotSnapshot _resolveSlot(DateTime slotStart) {
    final draft = _draftSlots
        .where((slot) => slot.start.isAtSameMomentAs(slotStart))
        .toList();
    if (draft.isNotEmpty) {
      return _SlotSnapshot(slot: draft.first, state: _SlotState.draft);
    }
    final committed = _committedSlots
        .where((slot) => slot.start.isAtSameMomentAs(slotStart))
        .toList();
    if (committed.isNotEmpty) {
      return _SlotSnapshot(slot: committed.first, state: _SlotState.committed);
    }
    return const _SlotSnapshot.empty();
  }

  Future<void> _handleSlotTap(DateTime slotStart) async {
    final snapshot = _resolveSlot(slotStart);
    if (snapshot.state == _SlotState.committed) {
      await _showCommittedSlotDetails(snapshot.slot!);
      return;
    }

    final availableLearners = _availableLearnersForSlot(slotStart);
    if (availableLearners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No learners available for this time slot.'),
        ),
      );
      return;
    }

    final existing = snapshot.slot;
    final result = await showModalBottomSheet<_SlotDraftResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _SlotEditorSheet(
          slotStart: slotStart,
          learnerOptions: availableLearners,
          existing: existing,
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _draftSlots.removeWhere((slot) => slot.start.isAtSameMomentAs(slotStart));
      if (!result.remove && result.learnerId != null) {
        final learner = _learnerOptions[result.learnerId]!;
        _draftSlots.add(
          _ScheduledSlot(
            start: slotStart,
            durationMinutes: result.durationMinutes ?? 60,
            learnerId: learner.id,
            learnerName: learner.displayName,
            learnerColors: learner.colors,
            isDraft: true,
            notes: result.notes,
          ),
        );
      }
    });
  }

  Future<void> _showCommittedSlotDetails(_ScheduledSlot slot) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return _CommittedSlotSheet(
          slot: slot,
          onCancel: () => _cancelLesson(slot),
        );
      },
    );
  }

  Future<void> _cancelLesson(_ScheduledSlot slot) async {
    final lessonId = slot.lessonId;
    if (lessonId == null) return;
    final instructorId = SupabaseService.currentUser?.id;
    int? remainingCancels;
    if (instructorId != null) {
      try {
        final used = await SupabaseService.getMonthlyCancellationCount(
          userId: instructorId,
          isInstructor: true,
        );
        final remaining = _instructorMonthlyCancelLimit - used;
        remainingCancels = remaining < 0 ? 0 : remaining;
      } catch (_) {}
    }

    if (remainingCancels != null && remainingCancels <= 0) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancel limit reached'),
          content: const Text(
            'You have used all monthly lesson cancellations. Please reach out to the learner directly to make changes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancel lesson?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cancel the lesson with ${slot.learnerName} on ${_formatDateTime(slot.start)}?',
                ),
                const SizedBox(height: 12),
                if (remainingCancels != null)
                  Text(
                    'You have $remainingCancels of $_instructorMonthlyCancelLimit cancellations left this month. Once you run out, you will need to contact the learner directly to make changes.',
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                  ),
                if (remainingCancels != null) const SizedBox(height: 4),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep lesson'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Cancel lesson'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    setState(() => _loading = true);
    try {
      await SupabaseService.updateLessonStatus(lessonId, 'cancelled');
      await _loadWeekSchedule();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Lesson with ${slot.learnerName} cancelled successfully.'),
        ),
      );
      AppNotifier.instance.notifyLessonsChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to cancel lesson: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  List<_LearnerOption> _availableLearnersForSlot(DateTime slotStart) {
    final dayKey = DateFormat('EEEE').format(slotStart).toLowerCase();
    return _learnerOptions.values
        .where((option) => option.isAvailableForSlot(dayKey, slotStart, 15))
        .where((option) =>
            !_learnerHasSlot(option.id, slotStart, includeDrafts: true))
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  bool _learnerHasSlot(String learnerId, DateTime slotStart,
      {bool includeDrafts = false}) {
    for (final slot in _committedSlots) {
      if (slot.learnerId == learnerId &&
          slot.start.isAtSameMomentAs(slotStart) &&
          !slot.isDraft) {
        return true;
      }
    }
    if (includeDrafts) {
      for (final slot in _draftSlots) {
        if (slot.learnerId == learnerId &&
            slot.start.isAtSameMomentAs(slotStart)) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _sendSchedule() async {
    if (_draftSlots.isEmpty) return;
    final instructorId = SupabaseService.currentUser?.id;
    if (instructorId == null) return;
    final instructorProfile = _instructorProfile;

    setState(() => _sending = true);
    try {
      for (final draft in List<_ScheduledSlot>.from(_draftSlots)) {
        final start = draft.start;
        final durationHours = draft.durationMinutes / 60.0;
        final end = start.add(Duration(minutes: draft.durationMinutes));
        final focus = _resolveFocusForLearner(draft.learnerId);
        final pickup = _resolvePickupForLearner(draft.learnerId);
        final cost = _deriveRate(instructorProfile, focus) * durationHours;
        final lessonDate = DateTime(start.year, start.month, start.day);
        final result = await SupabaseService.createLesson(
          learnerId: draft.learnerId,
          instructorId: instructorId,
          scheduledDate: start,
          startTime: DateFormat('HH:mm').format(start),
          endTime: DateFormat('HH:mm').format(end),
          duration: durationHours,
          cost: cost,
          notes: (draft.notes?.isNotEmpty ?? false)
              ? draft.notes
              : 'Scheduled via weekly planner',
          location: pickup,
          focus: focus,
          lessonDate: lessonDate,
        );
        if (result != null) {
          _committedSlots.add(
            draft.copyWith(
              isDraft: false,
              lessonId: result.id,
              notes: draft.notes,
            ),
          );
          _draftSlots.remove(draft);
        }
      }
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Schedule sent to learners.'),
        ),
      );
      AppNotifier.instance.notifyLessonsChanged();
      await _loadWeekSchedule();
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to send schedule: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _goToPreviousWeek() {
    if (_weekOffset == 0) return;
    setState(() {
      _weekOffset -= 1;
      _weekStart =
          _startOfWeek(DateTime.now()).add(Duration(days: 7 * _weekOffset));
    });
    _loadWeekSchedule();
  }

  void _goToNextWeek() {
    if (_weekOffset >= 1) return;
    setState(() {
      _weekOffset += 1;
      _weekStart =
          _startOfWeek(DateTime.now()).add(Duration(days: 7 * _weekOffset));
    });
    _loadWeekSchedule();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Schedule'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryBlue,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? _ScheduleErrorState(onRetry: _loadInitialData)
              : Column(
                  children: [
                    _buildWeekSelector(),
                    const SizedBox(height: 8),
                    _buildLegend(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: 7,
                        itemBuilder: (context, index) {
                          final day = _weekStart.add(Duration(days: index));
                          return _buildDaySection(day);
                        },
                      ),
                    ),
                    if (_draftSlots.isNotEmpty)
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _sending ? null : _sendSchedule,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: _sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : const Icon(Icons.send),
                              label: Text(
                                _sending
                                    ? 'Sending schedule...'
                                    : 'Send schedule to learners',
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildWeekSelector() {
    final formatter = DateFormat('MMM d');
    final label =
        '${formatter.format(_weekStart)} \u2013 ${formatter.format(_weekEnd)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _weekOffset == 0 ? null : _goToPreviousWeek,
            icon: const Icon(Icons.chevron_left),
          ),
          Column(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _weekOffset == 0 ? 'This week' : 'Next week',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          IconButton(
            onPressed: _weekOffset >= 1 ? null : _goToNextWeek,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    Widget legendItem(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          legendItem(_scheduledBaseColor.withOpacity(0.28), 'Scheduled'),
          legendItem(_draftBaseColor.withOpacity(0.35), 'Draft'),
          legendItem(_availableBaseColor.withOpacity(0.2), 'Available'),
        ],
      ),
    );
  }

  Widget _buildDaySection(DateTime day) {
    final dayKey = DateFormat('EEEE').format(day);
    final slots = _generateSlotsForDay(day);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$dayKey \u00B7 ${DateFormat('MMM d').format(day)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: slots.map((slot) => _buildSlotChip(day, slot)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotChip(DateTime day, DateTime slotStart) {
    final snapshot = _resolveSlot(slotStart);
    final label = DateFormat('h:mm a').format(slotStart);
    Color background;
    Color borderColor;
    Color titleColor;
    Color subtitleColor;
    Color? badgeColor;
    String? badgeLabel;
    String? subtitle;

    switch (snapshot.state) {
      case _SlotState.draft:
        final colors = snapshot.slot!.learnerColors;
        background =
            Color.alphaBlend(_draftBaseColor.withOpacity(0.10), colors.surface);
        borderColor =
            Color.alphaBlend(_draftBaseColor.withOpacity(0.22), colors.border);
        titleColor = colors.accentText;
        subtitleColor = colors.accent;
        badgeColor = _draftBaseColor;
        badgeLabel = 'Draft';
        subtitle =
            '${snapshot.slot!.learnerName} \u2022 ${snapshot.slot!.durationMinutes}m';
        break;
      case _SlotState.committed:
        final colors = snapshot.slot!.learnerColors;
        background = Color.alphaBlend(
            _scheduledBaseColor.withOpacity(0.08), colors.surfaceStrong);
        borderColor = Color.alphaBlend(
            _scheduledBaseColor.withOpacity(0.18), colors.border);
        titleColor = colors.accentText;
        subtitleColor = colors.accent;
        badgeColor = _scheduledBaseColor;
        badgeLabel = 'Booked';
        subtitle =
            '${snapshot.slot!.learnerName} \u2022 ${snapshot.slot!.durationMinutes}m';
        break;
      case _SlotState.empty:
        background = _availableBaseColor.withOpacity(0.16);
        borderColor = _availableBaseColor.withOpacity(0.5);
        titleColor = Colors.black87;
        subtitleColor = Colors.grey[600]!;
        break;
    }

    return GestureDetector(
      onTap: () => _handleSlotTap(slotStart),
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                ),
                if (badgeColor != null && badgeLabel != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: subtitleColor,
                  fontWeight: snapshot.state == _SlotState.empty
                      ? FontWeight.w500
                      : FontWeight.w600,
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                _availabilityWindowForTime(slotStart)?.toUpperCase() ?? '',
                style: TextStyle(
                  fontSize: 12,
                  color: subtitleColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String? _availabilityWindowForTime(DateTime slotStart) {
    final hour = slotStart.hour;
    if (hour == 7) return 'early';
    if (hour >= 8 && hour <= 12) return 'morning';
    if (hour >= 13 && hour <= 16) return 'afternoon';
    if (hour >= 17 && hour <= 20) return 'evening';
    return null;
  }

  static String _formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d \u00B7 h:mm a').format(dateTime);
  }

  String? _resolveFocusForLearner(String learnerId) {
    final option = _learnerOptions[learnerId];
    final focus = option?.learningFocus?.trim();
    if (focus != null && focus.isNotEmpty) return focus;
    return null;
  }

  String? _resolvePickupForLearner(String learnerId) {
    final option = _learnerOptions[learnerId];
    final preferred = option?.preferredLocations;
    if (preferred is List && preferred.isNotEmpty) {
      for (final entry in preferred) {
        if (entry is Map) {
          final label =
              (entry['label'] ?? entry['type'] ?? '').toString().trim();
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
    }
    return null;
  }

  double _deriveRate(Map<String, dynamic>? profile, String? focus) {
    double? asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    final offeringRates = profile?['offering_rates'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(profile!['offering_rates'] as Map)
        : const <String, dynamic>{};

    if (focus != null && focus.trim().isNotEmpty) {
      final normalized = focus.toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9]'),
            '',
          );
      for (final entry in offeringRates.entries) {
        final key = entry.key.toString().toLowerCase().replaceAll(
              RegExp(r'[^a-z0-9]'),
              '',
            );
        if (key == normalized) {
          final rate = asDouble(entry.value);
          if (rate != null && rate > 0) return rate;
        }
      }
    }

    final defaultRate = asDouble(profile?['default_rate']);
    if (defaultRate != null && defaultRate > 0) return defaultRate;
    return 0;
  }
}

class _LearnerOption {
  _LearnerOption({
    required this.id,
    required this.displayName,
    required this.weeklyAvailability,
    required this.recurring,
    required this.colors,
    this.avatarUrl,
    this.learningFocus,
    this.preferredLocations,
  });

  final String id;
  final String displayName;
  final Map<String, List<String>> weeklyAvailability;
  final bool recurring;
  final LearnerColorSet colors;
  final String? avatarUrl;
  final String? learningFocus;
  final List<dynamic>? preferredLocations;

  factory _LearnerOption.fromMap(Map<String, dynamic> map) {
    String? clean(dynamic value) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty || text == 'null') return null;
      return text;
    }

    final profile = map['learner'] as Map<String, dynamic>? ?? const {};
    final first = (profile['first_name'] as String?)?.trim() ?? '';
    final last = (profile['last_name'] as String?)?.trim() ?? '';
    final displayName =
        [first, last].where((v) => v.isNotEmpty).join(' ').trim();
    final learnerId = clean(map['learner_id']) ??
        clean(profile['id']) ??
        clean(map['profile_id']);

    final learnerProfile = map['learner_profile'] as Map<String, dynamic>?;
    final nestedProfile = learnerProfile?['profile'] as Map<String, dynamic>?;
    final avatarUrl = clean(profile['profile_image_url']) ??
        clean(learnerProfile?['profile_image_url']) ??
        clean(nestedProfile?['profile_image_url']) ??
        clean(map['requested_profile_url']);

    final availabilityRaw = map['weekly_availability'];
    final availability = <String, List<String>>{};
    if (availabilityRaw is Map) {
      availabilityRaw.forEach((key, value) {
        final slots = (value as List?)
                ?.whereType<String>()
                .map((slot) => slot.toLowerCase())
                .toList() ??
            const [];
        if (slots.isNotEmpty) {
          availability[key.toString().toLowerCase()] = slots;
        }
      });
    } else if (availabilityRaw is Iterable) {
      for (final entry in availabilityRaw) {
        if (entry is Map) {
          final day = entry['day']?.toString().toLowerCase();
          final slots = (entry['slots'] as List?)
                  ?.whereType<String>()
                  .map((slot) => slot.toLowerCase())
                  .toList() ??
              const [];
          if (day != null && slots.isNotEmpty) {
            availability[day] = slots;
          }
        }
      }
    }

    return _LearnerOption(
      id: learnerId ?? 'learner',
      displayName: (() {
        if (displayName.isNotEmpty) {
          return displayName;
        }
        final email = clean(profile['email']);
        if (email != null && email.isNotEmpty) {
          return email;
        }
        return 'Learner';
      })(),
      weeklyAvailability: availability,
      recurring: map['availability_recurring'] == true,
      colors: learnerColorForKey(
        learnerId ?? clean(profile['email']) ?? displayName,
      ),
      avatarUrl: avatarUrl,
      learningFocus:
          (map['learning_focus'] ?? map['learner_profile']?['learning_focus'])
              ?.toString(),
      preferredLocations: (map['preferred_locations'] ??
          map['learner_profile']?['preferred_locations']) as List<dynamic>?,
    );
  }

  static int? _minutesFromTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return (hour * 60) + minute;
  }

  bool isAvailableForSlot(String dayKey, DateTime slotStart, int durationMinutes) {
    final slots = weeklyAvailability[dayKey];
    if (slots == null || slots.isEmpty) return false;
    final startMinutes = (slotStart.hour * 60) + slotStart.minute;
    final endMinutes = startMinutes + durationMinutes;

    for (final slot in slots) {
      final normalized = slot.trim().toLowerCase();
      if (normalized.isEmpty) continue;

      if (normalized.contains('-')) {
        final parts = normalized.split('-');
        if (parts.length != 2) continue;
        final slotStartMinutes = _minutesFromTime(parts[0].trim());
        final slotEndMinutes = _minutesFromTime(parts[1].trim());
        if (slotStartMinutes == null || slotEndMinutes == null) continue;
        if (startMinutes >= slotStartMinutes && endMinutes <= slotEndMinutes) {
          return true;
        }
        continue;
      }

      final window = _InstructorAvailabilityScreenState._availabilityWindowForTime(
        slotStart,
      );
      if (window != null && normalized == window) {
        return true;
      }
    }
    return false;
  }
}

enum _SlotState { empty, draft, committed }

class _SlotSnapshot {
  const _SlotSnapshot({required this.slot, required this.state});
  const _SlotSnapshot.empty()
      : slot = null,
        state = _SlotState.empty;

  final _ScheduledSlot? slot;
  final _SlotState state;
}

class _ScheduledSlot {
  _ScheduledSlot({
    required this.start,
    required this.durationMinutes,
    required this.learnerId,
    required this.learnerName,
    required this.learnerColors,
    this.lessonId,
    this.isDraft = false,
    this.notes,
  });

  final DateTime start;
  final int durationMinutes;
  final String learnerId;
  final String learnerName;
  final LearnerColorSet learnerColors;
  final String? lessonId;
  final bool isDraft;
  final String? notes;

  _ScheduledSlot copyWith({
    DateTime? start,
    int? durationMinutes,
    String? learnerId,
    String? learnerName,
    LearnerColorSet? learnerColors,
    String? lessonId,
    bool? isDraft,
    String? notes,
  }) {
    return _ScheduledSlot(
      start: start ?? this.start,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      learnerId: learnerId ?? this.learnerId,
      learnerName: learnerName ?? this.learnerName,
      learnerColors: learnerColors ?? this.learnerColors,
      lessonId: lessonId ?? this.lessonId,
      isDraft: isDraft ?? this.isDraft,
      notes: notes ?? this.notes,
    );
  }

  static _ScheduledSlot? fromLessonRow(Map<String, dynamic> row) {
    String? clean(dynamic value) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty || text == 'null') return null;
      return text;
    }

    final scheduledAtRaw = row['scheduled_at']?.toString();
    if (scheduledAtRaw == null) return null;
    final scheduledAt = DateTime.tryParse(scheduledAtRaw)?.toLocal();
    if (scheduledAt == null) return null;

    final startTime = row['start_time']?.toString();
    final start = _combineDateAndTime(scheduledAt, startTime) ?? scheduledAt;

    final durationHours = (row['duration_hours'] as num?)?.toDouble() ?? 1.0;
    final durationMinutes = (durationHours * 60).round();
    final learner = row['learner'] as Map<String, dynamic>? ?? const {};
    final first = (learner['first_name'] as String?)?.trim() ?? '';
    final last = (learner['last_name'] as String?)?.trim() ?? '';
    final displayName =
        [first, last].where((value) => value.isNotEmpty).join(' ').trim();
    final learnerId = clean(row['learner_id']) ?? clean(learner['id']);

    return _ScheduledSlot(
      start: start,
      durationMinutes: durationMinutes,
      learnerId: learnerId ?? 'learner',
      learnerName: (() {
        if (displayName.isNotEmpty) {
          return displayName;
        }
        final email = clean(learner['email']);
        if (email != null && email.isNotEmpty) {
          return email;
        }
        return 'Learner';
      })(),
      learnerColors: learnerColorForKey(
        learnerId ?? clean(learner['email']) ?? displayName,
      ),
      lessonId: row['id']?.toString(),
      isDraft: false,
      notes: (row['notes'] ?? '').toString(),
    );
  }

  static DateTime? _combineDateAndTime(DateTime date, String? time) {
    if (time == null || time.isEmpty) return date;
    final parts = time.split(':');
    if (parts.length < 2) return date;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return date;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}

class _SlotEditorSheet extends StatefulWidget {
  const _SlotEditorSheet({
    required this.slotStart,
    required this.learnerOptions,
    this.existing,
  });

  final DateTime slotStart;
  final List<_LearnerOption> learnerOptions;
  final _ScheduledSlot? existing;

  @override
  State<_SlotEditorSheet> createState() => _SlotEditorSheetState();
}

class _SlotEditorSheetState extends State<_SlotEditorSheet> {
  late String? _selectedLearnerId;
  late int _selectedDuration;
  late TextEditingController _notesController;
  late TextEditingController _learnerSearchController;
  String _learnerSearchQuery = '';

  List<_LearnerOption> get _availableLearnersForDuration {
    final dayKey = DateFormat('EEEE').format(widget.slotStart).toLowerCase();
    return widget.learnerOptions
        .where(
          (option) =>
              option.isAvailableForSlot(dayKey, widget.slotStart, _selectedDuration),
        )
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  List<_LearnerOption> get _filteredLearners {
    final query = _learnerSearchQuery.trim().toLowerCase();
    final options = _availableLearnersForDuration;
    if (query.isEmpty) {
      return options;
    }
    final matches = options
        .where(
          (option) => option.displayName.toLowerCase().contains(query),
        )
        .toList();
    if (_selectedLearnerId != null &&
        !matches.any((option) => option.id == _selectedLearnerId)) {
      final selected = options.where((option) => option.id == _selectedLearnerId);
      matches.insertAll(0, selected);
    }
    return matches;
  }

  _LearnerOption? get _selectedLearner {
    final learnerId = _selectedLearnerId;
    if (learnerId == null) return null;
    for (final option in _availableLearnersForDuration) {
      if (option.id == learnerId) return option;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _selectedDuration = widget.existing?.durationMinutes ?? 60;
    final availableForInitialDuration = _availableLearnersForDuration;
    _selectedLearnerId = widget.existing?.learnerId;
    if (_selectedLearnerId == null ||
        !availableForInitialDuration.any(
          (option) => option.id == _selectedLearnerId,
        )) {
      _selectedLearnerId = availableForInitialDuration.isNotEmpty
          ? availableForInitialDuration.first.id
          : null;
    }
    _learnerSearchController = TextEditingController();
    _notesController =
        TextEditingController(text: widget.existing?.notes ?? '');
  }

  @override
  void dispose() {
    _learnerSearchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableLearners = _filteredLearners;
    final selectedLearner = _selectedLearner;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            12,
        left: 16,
        right: 16,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Schedule ${DateFormat('EEE, MMM d \u00B7 h:mm a').format(widget.slotStart)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _learnerSearchController,
            onChanged: (value) {
              setState(() => _learnerSearchQuery = value);
            },
            decoration: const InputDecoration(
              hintText: 'Search learners',
              prefixIcon: Icon(Icons.search_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Learner',
              border: OutlineInputBorder(),
            ),
            value: _selectedLearnerId,
            items: availableLearners
                .map(
                  (option) => DropdownMenuItem<String>(
                    value: option.id,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundImage: option.avatarUrl != null &&
                                  option.avatarUrl!.trim().isNotEmpty
                              ? NetworkImage(option.avatarUrl!)
                              : null,
                          backgroundColor: option.colors.surfaceStrong,
                          child: option.avatarUrl == null ||
                                  option.avatarUrl!.trim().isEmpty
                              ? Text(
                                  option.displayName.isNotEmpty
                                      ? option.displayName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: option.colors.accentText,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 180,
                          child: Text(
                            option.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedLearnerId = value),
            hint: const Text('Select learner'),
          ),
          if (availableLearners.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'No learners are available for the selected duration at this time.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(
              labelText: 'Duration',
              border: OutlineInputBorder(),
            ),
            value: _selectedDuration,
            items: _InstructorAvailabilityScreenState._durationOptions
                .map(
                  (value) => DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value minutes'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedDuration = value ?? 60;
                final availableForDuration = _availableLearnersForDuration;
                if (!availableForDuration.any(
                  (option) => option.id == _selectedLearnerId,
                )) {
                  _selectedLearnerId = availableForDuration.isNotEmpty
                      ? availableForDuration.first.id
                      : null;
                }
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Add lesson notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (widget.existing != null)
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(
                      const _SlotDraftResult(remove: true),
                    );
                  },
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove'),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _selectedLearnerId == null
                    ? null
                    : () {
                        Navigator.of(context).pop(
                          _SlotDraftResult(
                            learnerId: _selectedLearnerId,
                            durationMinutes: _selectedDuration,
                            notes: _notesController.text.trim(),
                          ),
                        );
                      },
                child: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SlotDraftResult {
  const _SlotDraftResult({
    this.learnerId,
    this.durationMinutes,
    this.remove = false,
    this.notes,
  });

  final String? learnerId;
  final int? durationMinutes;
  final bool remove;
  final String? notes;
}

class _CommittedSlotSheet extends StatelessWidget {
  const _CommittedSlotSheet({
    required this.slot,
    required this.onCancel,
  });

  final _ScheduledSlot slot;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = slot.learnerColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              'Lesson with ${slot.learnerName}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.accentText,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(_InstructorAvailabilityScreenState._formatDateTime(
                  slot.start)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.timelapse, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text('${slot.durationMinutes} minutes'),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onCancel();
                },
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel lesson'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleErrorState extends StatelessWidget {
  const _ScheduleErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40, color: AppColors.error),
          const SizedBox(height: 12),
          const Text('Unable to load schedule right now.'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
