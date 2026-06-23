import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_radii.dart';
import '../../services/app_notifier.dart';
import '../../services/supabase_service.dart';
import '../../utils/learner_color_utils.dart';
import '../../utils/lesson_request_utils.dart';

class InstructorAvailabilityScreen extends StatefulWidget {
  const InstructorAvailabilityScreen({super.key});

  @override
  State<InstructorAvailabilityScreen> createState() =>
      _InstructorAvailabilityScreenState();
}

class _InstructorAvailabilityScreenState
    extends State<InstructorAvailabilityScreen> {
  static const List<int> _standardSlotHours = [
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
  static const List<int> _afterHoursSlotHours = [
    5,
    6,
    21,
    22,
    23,
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
  bool _showAfterHours = false;
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
        ..addEntries(
          learners
              .whereType<Map<dynamic, dynamic>>()
              .map(
                (raw) => Map<String, dynamic>.from(
                  raw.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .map((data) => _LearnerOption.fromMap(data))
              .map((option) => MapEntry(option.id, option)),
        );

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
    final hours = [
      if (_showAfterHours) ..._afterHoursSlotHours,
      ..._standardSlotHours,
    ]..sort();
    return hours
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

  List<_ScheduledSlot> _slotsForHour(DateTime hourStart) {
    final hourEnd = hourStart.add(const Duration(hours: 1));
    return [
      ..._committedSlots,
      ..._draftSlots,
    ].where((slot) => slot.overlaps(hourStart, hourEnd)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  List<DateTime> _quarterStarts(DateTime hourStart) {
    return List.generate(
      4,
      (index) => hourStart.add(Duration(minutes: index * 15)),
    );
  }

  bool _hasSlotOverlap(
    DateTime start,
    int durationMinutes, {
    _ScheduledSlot? excluding,
  }) {
    final end = start.add(Duration(minutes: durationMinutes));
    for (final slot in [..._committedSlots, ..._draftSlots]) {
      if (identical(slot, excluding)) continue;
      if (slot.overlaps(start, end)) return true;
    }
    return false;
  }

  bool _hasOpenQuarter(DateTime hourStart) {
    return _quarterStarts(hourStart).any(
      (start) => !_hasSlotOverlap(start, 15),
    );
  }

  Future<void> _handleSlotTap(DateTime slotStart) async {
    final hourSlots = _slotsForHour(slotStart);
    _ScheduledSlot? draftAtHourStart;
    _ScheduledSlot? firstCommitted;
    for (final slot in hourSlots) {
      if (slot.isDraft && slot.start.isAtSameMomentAs(slotStart)) {
        draftAtHourStart = slot;
      }
      if (!slot.isDraft && firstCommitted == null) {
        firstCommitted = slot;
      }
    }
    if (hourSlots.isNotEmpty && !_hasOpenQuarter(slotStart)) {
      if (firstCommitted != null) {
        await _showCommittedSlotDetails(firstCommitted);
        return;
      }
    }

    if (hourSlots.length == 1 &&
        !hourSlots.first.isDraft &&
        hourSlots.first.start.isAtSameMomentAs(slotStart) &&
        hourSlots.first.durationMinutes >= 60) {
      await _showCommittedSlotDetails(hourSlots.first);
      return;
    }

    final availableLearners = _learnerOptions.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    if (availableLearners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No learners available for this time slot.'),
        ),
      );
      return;
    }

    final existing = draftAtHourStart;
    final result = await showModalBottomSheet<_SlotDraftResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _SlotEditorSheet(
          slotStart: slotStart,
          learnerOptions: availableLearners,
          existing: existing,
          existingHourSlots: hourSlots,
          onExistingSlotTap: (slot) {
            if (!slot.isDraft) {
              _editCommittedLesson(slot);
            }
          },
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      final resultStart = result.start ?? slotStart;
      _draftSlots
          .removeWhere((slot) => slot.start.isAtSameMomentAs(resultStart));
      if (!result.remove && result.learnerId != null) {
        final learner = _learnerOptions[result.learnerId]!;
        _draftSlots.add(
          _ScheduledSlot(
            start: resultStart,
            durationMinutes: result.durationMinutes ?? 60,
            learnerId: learner.id,
            learnerName: learner.displayName,
            learnerColors: learner.colors,
            isExternalLearner: learner.isExternalLearner,
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
          onEdit: () => _editCommittedLesson(slot),
        );
      },
    );
  }

  Future<bool> _confirmLessonCancellation(
    _ScheduledSlot slot, {
    String title = 'Cancel lesson?',
    String confirmLabel = 'Cancel lesson',
    String? message,
  }) async {
    final lessonId = slot.lessonId;
    if (lessonId == null) return false;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(
              message ??
                  'Cancel the lesson with ${slot.learnerName} on ${_formatDateTime(slot.start)}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep lesson'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
    return confirmed;
  }

  Future<void> _cancelLesson(_ScheduledSlot slot) async {
    final lessonId = slot.lessonId;
    if (lessonId == null) return;
    final confirmed = await _confirmLessonCancellation(slot);
    if (!confirmed) return;

    setState(() => _loading = true);
    try {
      await SupabaseService.updateLessonStatus(lessonId, 'cancelled');
      await _loadWeekSchedule();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lesson with ${slot.learnerName} cancelled successfully.',
          ),
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

  Future<void> _replaceCommittedLesson(_ScheduledSlot slot) async {
    final lessonId = slot.lessonId;
    final instructorId = SupabaseService.currentUser?.id;
    if (lessonId == null || instructorId == null) return;

    final availableLearners = _availableLearnersForSlot(
      slot.start,
    ).where((learner) => learner.id != slot.learnerId).toList();
    if (availableLearners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No other learners are available for this booked slot.',
          ),
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<_SlotDraftResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _SlotEditorSheet(
          slotStart: slot.start,
          learnerOptions: availableLearners,
          title: 'Replace ${slot.learnerName}',
          saveLabel: 'Replace lesson',
        );
      },
    );
    if (!mounted || result == null || result.learnerId == null) return;

    final learner = _learnerOptions[result.learnerId];
    if (learner == null) return;
    final confirmed = await _confirmLessonCancellation(
      slot,
      title: 'Replace booked lesson?',
      confirmLabel: 'Replace lesson',
      message:
          'This will cancel ${slot.learnerName} at ${_formatDateTime(slot.start)} and book ${learner.displayName} in this slot.',
    );
    if (!confirmed) return;

    setState(() => _loading = true);
    try {
      final cancelled = await SupabaseService.updateLessonStatus(
        lessonId,
        'cancelled',
      );
      if (cancelled == null) {
        throw Exception('Existing lesson could not be cancelled.');
      }
      final created = await _createLessonForDraft(
        draft: _ScheduledSlot(
          start: slot.start,
          durationMinutes: result.durationMinutes ?? slot.durationMinutes,
          learnerId: learner.id,
          learnerName: learner.displayName,
          learnerColors: learner.colors,
          isExternalLearner: learner.isExternalLearner,
          isDraft: true,
          notes: result.notes,
        ),
        instructorId: instructorId,
      );
      if (created == null) {
        throw Exception('Replacement lesson could not be created.');
      }
      await _loadWeekSchedule();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${slot.learnerName} cancelled. ${learner.displayName} booked.',
          ),
        ),
      );
      AppNotifier.instance.notifyLessonsChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to replace lesson: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _moveCommittedLesson(_ScheduledSlot slot) async {
    final lessonId = slot.lessonId;
    if (lessonId == null) return;

    final target = await showModalBottomSheet<_MoveSlotResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _MoveLessonSheet(
          learnerName: slot.learnerName,
          currentStart: slot.start,
          candidateStarts: _moveTargetsForLearner(slot),
        );
      },
    );
    if (!mounted || target == null) return;

    final start = target.start;
    final end = start.add(Duration(minutes: slot.durationMinutes));
    final durationHours = slot.durationMinutes / 60.0;
    final focus = _resolveFocusForLearner(slot.learnerId);
    final pickup = _resolvePickupForLearner(slot.learnerId);
    final cost = _deriveRate(_instructorProfile, focus) * durationHours;
    final notes = slot.notes?.trim();

    setState(() => _loading = true);
    try {
      final updated = await SupabaseService.updateScheduledLesson(
        lessonId: lessonId,
        scheduledDate: start,
        startTime: DateFormat('HH:mm').format(start),
        endTime: DateFormat('HH:mm').format(end),
        duration: durationHours,
        cost: cost,
        notes: notes != null && notes.isNotEmpty ? notes : null,
        location: pickup,
        focus: focus,
        lessonDate: DateTime(start.year, start.month, start.day),
      );
      if (updated == null) {
        throw Exception('Lesson could not be moved.');
      }
      await _loadWeekSchedule();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${slot.learnerName} moved to ${_formatDateTime(start)}.',
          ),
        ),
      );
      AppNotifier.instance.notifyLessonsChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to move lesson: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _editCommittedLesson(_ScheduledSlot slot) async {
    final lessonId = slot.lessonId;
    if (lessonId == null) return;

    final hourStart = DateTime(
      slot.start.year,
      slot.start.month,
      slot.start.day,
      slot.start.hour,
    );
    final hourSlots = _slotsForHour(hourStart);
    var editableSlot = slot;
    for (final candidate in hourSlots) {
      if (slot.lessonId != null && candidate.lessonId == slot.lessonId) {
        editableSlot = candidate;
        break;
      }
      if (candidate.start.isAtSameMomentAs(slot.start) &&
          candidate.learnerId == slot.learnerId) {
        editableSlot = candidate;
        break;
      }
    }

    final availableLearners = _learnerOptions.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    final hasCurrentLearner = availableLearners.any(
      (learner) => learner.id == editableSlot.learnerId,
    );
    if (!hasCurrentLearner) {
      availableLearners.insert(
        0,
        _LearnerOption(
          id: editableSlot.learnerId,
          displayName: editableSlot.learnerName,
          colors: editableSlot.learnerColors,
          weeklyAvailability: const {},
          recurring: true,
          preferredLocations: const [],
          isExternalLearner: editableSlot.isExternalLearner,
        ),
      );
    }

    final result = await showModalBottomSheet<_SlotDraftResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _SlotEditorSheet(
          slotStart: hourStart,
          learnerOptions: availableLearners,
          existing: editableSlot,
          existingHourSlots: hourSlots,
          onExistingSlotTap: (slot) {
            if (!slot.isDraft) {
              _editCommittedLesson(slot);
            }
          },
          title: 'Edit lesson with ${editableSlot.learnerName}',
          saveLabel: 'Save changes',
        );
      },
    );
    if (!mounted || result == null) return;

    if (result.remove) {
      await _cancelLesson(editableSlot);
      return;
    }

    _LearnerOption? selectedLearner;
    if (result.learnerId != null) {
      for (final learner in availableLearners) {
        if (learner.id == result.learnerId) {
          selectedLearner = learner;
          break;
        }
      }
    }
    if (selectedLearner == null) return;

    final start = result.start ?? editableSlot.start;
    final durationMinutes =
        result.durationMinutes ?? editableSlot.durationMinutes;
    final end = start.add(Duration(minutes: durationMinutes));
    final durationHours = durationMinutes / 60.0;
    final focus = _resolveFocusForLearner(selectedLearner.id);
    final pickup = _resolvePickupForLearner(selectedLearner.id);
    final cost = _deriveRate(_instructorProfile, focus) * durationHours;
    final notes = result.notes?.trim();

    setState(() => _loading = true);
    try {
      final updated = await SupabaseService.updateScheduledLesson(
        lessonId: lessonId,
        scheduledDate: start,
        startTime: DateFormat('HH:mm').format(start),
        endTime: DateFormat('HH:mm').format(end),
        duration: durationHours,
        cost: cost,
        notes: notes != null && notes.isNotEmpty ? notes : null,
        location: pickup,
        focus: focus,
        lessonDate: DateTime(start.year, start.month, start.day),
      );
      if (updated == null) {
        throw Exception('Lesson could not be updated.');
      }
      await _loadWeekSchedule();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lesson with ${selectedLearner.displayName} updated.',
          ),
        ),
      );
      AppNotifier.instance.notifyLessonsChanged();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update lesson: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  List<_LearnerOption> _availableLearnersForSlot(DateTime slotStart) {
    final dayKey = DateFormat('EEEE').format(slotStart).toLowerCase();
    return _learnerOptions.values
        .where((option) => option.isAvailableForSlot(dayKey, slotStart, 15))
        .where(
          (option) => !_learnerHasOverlap(option.id, slotStart, 15,
              includeDrafts: true),
        )
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  bool _learnerHasOverlap(
    String learnerId,
    DateTime slotStart,
    int durationMinutes, {
    bool includeDrafts = false,
  }) {
    final slotEnd = slotStart.add(Duration(minutes: durationMinutes));
    for (final slot in _committedSlots) {
      if (slot.learnerId == learnerId &&
          slot.overlaps(slotStart, slotEnd) &&
          !slot.isDraft) {
        return true;
      }
    }
    if (includeDrafts) {
      for (final slot in _draftSlots) {
        if (slot.learnerId == learnerId && slot.overlaps(slotStart, slotEnd)) {
          return true;
        }
      }
    }
    return false;
  }

  List<DateTime> _moveTargetsForLearner(_ScheduledSlot slot) {
    final targets = <DateTime>[];
    for (var dayOffset = 0; dayOffset < 7; dayOffset++) {
      final day = _weekStart.add(Duration(days: dayOffset));
      final dayKey = DateFormat('EEEE').format(day).toLowerCase();
      final learner = _learnerOptions[slot.learnerId];
      if (learner == null) continue;
      for (final candidate in _generateSlotsForDay(day)) {
        if (candidate.isAtSameMomentAs(slot.start)) continue;
        if (_hasSlotOverlap(candidate, slot.durationMinutes, excluding: slot)) {
          continue;
        }
        if (!learner.isAvailableForSlot(
          dayKey,
          candidate,
          slot.durationMinutes,
        )) {
          continue;
        }
        targets.add(candidate);
      }
    }
    targets.sort((a, b) => a.compareTo(b));
    return targets;
  }

  Future<dynamic> _createLessonForDraft({
    required _ScheduledSlot draft,
    required String instructorId,
  }) async {
    final start = draft.start;
    final durationHours = draft.durationMinutes / 60.0;
    final end = start.add(Duration(minutes: draft.durationMinutes));
    final focus = _resolveFocusForLearner(draft.learnerId);
    final pickup = _resolvePickupForLearner(draft.learnerId);
    final cost = _deriveRate(_instructorProfile, focus) * durationHours;
    final lessonDate = DateTime(start.year, start.month, start.day);
    final notes = draft.notes?.trim();
    return SupabaseService.createLesson(
      learnerId: draft.isExternalLearner ? null : draft.learnerId,
      externalLearnerId: draft.isExternalLearner ? draft.learnerId : null,
      instructorId: instructorId,
      scheduledDate: start,
      startTime: DateFormat('HH:mm').format(start),
      endTime: DateFormat('HH:mm').format(end),
      duration: durationHours,
      cost: cost,
      notes: notes != null && notes.isNotEmpty ? notes : null,
      location: pickup,
      focus: focus,
      lessonDate: lessonDate,
    );
  }

  Future<void> _sendSchedule() async {
    if (_draftSlots.isEmpty) return;
    final instructorId = SupabaseService.currentUser?.id;
    if (instructorId == null) return;

    setState(() => _sending = true);
    try {
      for (final draft in List<_ScheduledSlot>.from(_draftSlots)) {
        final result = await _createLessonForDraft(
          draft: draft,
          instructorId: instructorId,
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
        const SnackBar(content: Text('Schedule sent to learners.')),
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
      _weekStart = _startOfWeek(
        DateTime.now(),
      ).add(Duration(days: 7 * _weekOffset));
    });
    _loadWeekSchedule();
  }

  void _goToNextWeek() {
    if (_weekOffset >= 1) return;
    setState(() {
      _weekOffset += 1;
      _weekStart = _startOfWeek(
        DateTime.now(),
      ).add(Duration(days: 7 * _weekOffset));
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
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildLegend(),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: _buildAfterHoursToggle(),
                          ),
                        ],
                      ),
                    ),
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
                                          Colors.white,
                                        ),
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
    Widget legendItem(Color color, String label, {Color? borderColor}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border:
                  borderColor != null ? Border.all(color: borderColor) : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        legendItem(_scheduledBaseColor.withOpacity(0.28), 'Scheduled'),
        legendItem(_draftBaseColor.withOpacity(0.35), 'Draft'),
        legendItem(
          Colors.white,
          'Available',
          borderColor: _availableBaseColor,
        ),
      ],
    );
  }

  Widget _buildAfterHoursToggle() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'After hours',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(width: 4),
          Transform.scale(
            scale: 0.72,
            child: Switch.adaptive(
              value: _showAfterHours,
              activeColor: AppColors.primaryBlue,
              onChanged: (value) => setState(() => _showAfterHours = value),
            ),
          ),
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
    final hourSlots = _slotsForHour(slotStart);
    final hasSlots = hourSlots.isNotEmpty;
    final hasDraft = hourSlots.any((slot) => slot.isDraft);
    final isFullyOccupied = !_hasOpenQuarter(slotStart);
    final primarySlot = hasSlots ? hourSlots.first : null;
    final label = DateFormat('h:mm a').format(slotStart);
    Color background;
    Color borderColor;
    Color titleColor;
    Color subtitleColor;
    Color? badgeColor;
    String? badgeLabel;
    String? subtitle;

    if (hasSlots) {
      final colors = primarySlot!.learnerColors;
      background = Colors.white;
      borderColor = isFullyOccupied
          ? Color.alphaBlend(
              _scheduledBaseColor.withOpacity(0.20),
              colors.border,
            )
          : _availableBaseColor;
      titleColor = colors.accentText;
      subtitleColor = colors.accent;
      badgeColor = hasDraft ? _draftBaseColor : _scheduledBaseColor;
      badgeLabel = hasDraft ? 'Draft' : 'Booked';
      subtitle = hourSlots.length == 1
          ? '${primarySlot.learnerName} • ${primarySlot.durationMinutes}m'
          : '${hourSlots.length} bookings • ${_openMinutesForHour(slotStart)}m open';
    } else {
      background = Colors.white;
      borderColor = _availableBaseColor;
      titleColor = Colors.black87;
      subtitleColor = Colors.grey[600]!;
    }

    return GestureDetector(
      onTap: () => _handleSlotTap(slotStart),
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: hasSlots ? 1.5 : 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHourSegmentBar(slotStart, hourSlots),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                ),
                if (badgeColor != null && badgeLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: subtitleColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Text(
                _availabilityWindowForTime(slotStart)?.toUpperCase() ?? '',
                style: TextStyle(fontSize: 12, color: subtitleColor),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _openMinutesForHour(DateTime hourStart) {
    return _quarterStarts(hourStart)
            .where((start) => !_hasSlotOverlap(start, 15))
            .length *
        15;
  }

  Widget _buildHourSegmentBar(DateTime hourStart, List<_ScheduledSlot> slots) {
    final quarterStarts = _quarterStarts(hourStart);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _availableBaseColor.withOpacity(0.45)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            for (var index = 0; index < quarterStarts.length; index++)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _segmentColorForQuarter(quarterStarts[index], slots),
                    border: index == 0
                        ? null
                        : Border(
                            left: BorderSide(
                              color: Colors.black,
                              width: 1.2,
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _segmentColorForQuarter(
    DateTime quarterStart,
    List<_ScheduledSlot> slots,
  ) {
    final quarterEnd = quarterStart.add(const Duration(minutes: 15));
    _ScheduledSlot? slot;
    for (final entry in slots) {
      if (entry.overlaps(quarterStart, quarterEnd)) {
        slot = entry;
        break;
      }
    }
    if (slot == null) return Colors.white;
    return slot.isDraft
        ? Color.alphaBlend(
            _draftBaseColor.withOpacity(0.28),
            slot.learnerColors.accent,
          )
        : slot.learnerColors.accent;
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
    required this.isExternalLearner,
    this.avatarUrl,
    this.learningFocus,
    this.preferredLocations,
  });

  final String id;
  final String displayName;
  final Map<String, List<String>> weeklyAvailability;
  final bool recurring;
  final LearnerColorSet colors;
  final bool isExternalLearner;
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
    final fallbackDisplayName = [
      first,
      last,
    ].where((v) => v.isNotEmpty).join(' ').trim();
    final displayName = formatLessonRequestLearnerName(map);
    final learnerId = clean(map['learner_id']) ??
        clean(map['external_learner_id']) ??
        clean(profile['id']) ??
        clean(map['profile_id']);
    final isExternalLearner = map['is_external_learner'] == true ||
        map['is_offline'] == true ||
        clean(map['external_learner_id']) != null;

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
        if (displayName.isNotEmpty && displayName != 'Learner') {
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
      isExternalLearner: isExternalLearner,
      colors: learnerColorForKey(
        learnerId ?? clean(profile['email']) ?? fallbackDisplayName,
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

  bool isAvailableForSlot(
    String dayKey,
    DateTime slotStart,
    int durationMinutes,
  ) {
    final slots = weeklyAvailability[dayKey];
    if (slots == null || slots.isEmpty) return isExternalLearner;
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

      final window =
          _InstructorAvailabilityScreenState._availabilityWindowForTime(
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
    this.isExternalLearner = false,
    this.notes,
  });

  final DateTime start;
  final int durationMinutes;
  final String learnerId;
  final String learnerName;
  final LearnerColorSet learnerColors;
  final String? lessonId;
  final bool isDraft;
  final bool isExternalLearner;
  final String? notes;

  DateTime get end => start.add(Duration(minutes: durationMinutes));

  bool overlaps(DateTime rangeStart, DateTime rangeEnd) {
    return start.isBefore(rangeEnd) && end.isAfter(rangeStart);
  }

  _ScheduledSlot copyWith({
    DateTime? start,
    int? durationMinutes,
    String? learnerId,
    String? learnerName,
    LearnerColorSet? learnerColors,
    String? lessonId,
    bool? isDraft,
    bool? isExternalLearner,
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
      isExternalLearner: isExternalLearner ?? this.isExternalLearner,
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
    final endTime = row['end_time']?.toString();
    final parsedEnd = _combineDateAndTime(scheduledAt, endTime);
    var durationMinutes = 60;
    if (parsedEnd != null && parsedEnd.isAfter(start)) {
      durationMinutes = parsedEnd.difference(start).inMinutes;
    } else if (row['duration_minutes'] is num) {
      durationMinutes = (row['duration_minutes'] as num).round();
    } else {
      final durationHours = (row['duration_hours'] as num?)?.toDouble() ?? 1.0;
      durationMinutes = (durationHours * 60).round();
    }
    if (durationMinutes <= 0) {
      durationMinutes = 60;
    }
    final learner = row['learner'] as Map<String, dynamic>? ?? const {};
    final first = (learner['first_name'] as String?)?.trim() ?? '';
    final last = (learner['last_name'] as String?)?.trim() ?? '';
    final rowDisplayName = clean(row['learner_name']);
    final displayName = [
      first,
      last,
    ].where((value) => value.isNotEmpty).join(' ').trim();
    final learnerId = clean(row['learner_id']) ??
        clean(row['external_learner_id']) ??
        clean(learner['id']);
    final isExternalLearner = clean(row['external_learner_id']) != null ||
        row['is_external_learner'] == true ||
        learner['is_external'] == true ||
        learner['is_offline'] == true;

    return _ScheduledSlot(
      start: start,
      durationMinutes: durationMinutes,
      learnerId: learnerId ?? 'learner',
      learnerName: (() {
        if (rowDisplayName != null && rowDisplayName.isNotEmpty) {
          return rowDisplayName;
        }
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
      isExternalLearner: isExternalLearner,
      notes: clean(row['notes']),
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
    this.title,
    this.saveLabel = 'Save',
    this.existing,
    this.existingHourSlots = const [],
    this.onExistingSlotTap,
  });

  final DateTime slotStart;
  final List<_LearnerOption> learnerOptions;
  final String? title;
  final String saveLabel;
  final _ScheduledSlot? existing;
  final List<_ScheduledSlot> existingHourSlots;
  final ValueChanged<_ScheduledSlot>? onExistingSlotTap;

  @override
  State<_SlotEditorSheet> createState() => _SlotEditorSheetState();
}

class _SlotEditorSheetState extends State<_SlotEditorSheet> {
  late DateTime _selectedStart;
  late String? _selectedLearnerId;
  late int _selectedDuration;
  late TextEditingController _notesController;
  late TextEditingController _learnerSearchController;
  String _learnerSearchQuery = '';

  List<DateTime> get _quarterStarts {
    return List.generate(
      4,
      (index) => widget.slotStart.add(Duration(minutes: index * 15)),
    );
  }

  bool _isExistingSlot(_ScheduledSlot slot) {
    final existing = widget.existing;
    if (existing == null) return false;
    if (identical(slot, existing)) return true;
    if (existing.lessonId != null && slot.lessonId == existing.lessonId) {
      return true;
    }
    return slot.start.isAtSameMomentAs(existing.start) &&
        slot.learnerId == existing.learnerId &&
        slot.durationMinutes == existing.durationMinutes;
  }

  bool _hasExistingOverlap(DateTime start, int durationMinutes) {
    final end = start.add(Duration(minutes: durationMinutes));
    for (final slot in widget.existingHourSlots) {
      if (_isExistingSlot(slot)) continue;
      if (slot.overlaps(start, end)) return true;
    }
    return false;
  }

  List<DateTime> get _availableStartsForDuration {
    final hourEnd = widget.slotStart.add(const Duration(hours: 1));
    return _quarterStarts.where((start) {
      final end = start.add(Duration(minutes: _selectedDuration));
      if (end.isAfter(hourEnd)) return false;
      if (_hasExistingOverlap(start, _selectedDuration)) return false;
      final dayKey = DateFormat('EEEE').format(start).toLowerCase();
      return widget.learnerOptions.any(
        (option) => option.isAvailableForSlot(dayKey, start, _selectedDuration),
      );
    }).toList();
  }

  List<_LearnerOption> get _availableLearnersForDuration {
    final dayKey = DateFormat('EEEE').format(_selectedStart).toLowerCase();
    return widget.learnerOptions
        .where(
          (option) => option.isAvailableForSlot(
            dayKey,
            _selectedStart,
            _selectedDuration,
          ),
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
        .where((option) => option.displayName.toLowerCase().contains(query))
        .toList();
    if (_selectedLearnerId != null &&
        !matches.any((option) => option.id == _selectedLearnerId)) {
      final selected = options.where(
        (option) => option.id == _selectedLearnerId,
      );
      matches.insertAll(0, selected);
    }
    return matches;
  }

  @override
  void initState() {
    super.initState();
    _selectedDuration = widget.existing?.durationMinutes ?? 60;
    _selectedStart = widget.existing?.start ?? widget.slotStart;
    if (widget.existing == null) {
      for (final duration in const [60, 45, 30, 15]) {
        _selectedDuration = duration;
        final starts = _availableStartsForDuration;
        if (starts.isNotEmpty) {
          _selectedStart = starts.first;
          break;
        }
      }
    }
    final startsForInitialDuration = _availableStartsForDuration;
    if (!startsForInitialDuration.any(
      (start) => start.isAtSameMomentAs(_selectedStart),
    )) {
      _selectedStart = startsForInitialDuration.isNotEmpty
          ? startsForInitialDuration.first
          : widget.slotStart;
    }
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
    _notesController = TextEditingController(
      text: widget.existing?.notes ?? '',
    );
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
    final hasAvailableStart = _availableStartsForDuration.any(
      (start) => start.isAtSameMomentAs(_selectedStart),
    );
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.9;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            12,
        left: 16,
        right: 16,
        top: 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title ??
                    'Schedule ${DateFormat('EEE, MMM d \u00B7 h:mm a').format(widget.slotStart)}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if (widget.existingHourSlots.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'This hour',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final slot in widget.existingHourSlots)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: widget.onExistingSlotTap == null
                                  ? null
                                  : () {
                                      Navigator.of(context).pop();
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        widget.onExistingSlotTap?.call(slot);
                                      });
                                    },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: slot.isDraft
                                            ? Color.alphaBlend(
                                                _InstructorAvailabilityScreenState
                                                    ._draftBaseColor
                                                    .withOpacity(0.22),
                                                slot.learnerColors
                                                    .surfaceStrong,
                                              )
                                            : slot.learnerColors.surfaceStrong,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${DateFormat('h:mm a').format(slot.start)} • ${slot.learnerName} • ${slot.durationMinutes}m',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: slot.learnerColors.accentText,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      slot.isDraft ? 'Draft' : 'Booked',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: slot.isDraft
                                            ? _InstructorAvailabilityScreenState
                                                ._draftBaseColor
                                            : _InstructorAvailabilityScreenState
                                                ._scheduledBaseColor,
                                      ),
                                    ),
                                    if (widget.onExistingSlotTap != null) ...[
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.edit_rounded,
                                        size: 15,
                                        color: AppColors.mutedForeground,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
              DropdownButtonFormField<DateTime>(
                decoration: const InputDecoration(
                  labelText: 'Start time',
                  border: OutlineInputBorder(),
                ),
                value: _availableStartsForDuration.any(
                  (start) => start.isAtSameMomentAs(_selectedStart),
                )
                    ? _selectedStart
                    : null,
                items: _availableStartsForDuration
                    .map(
                      (value) => DropdownMenuItem<DateTime>(
                        value: value,
                        child: Text(DateFormat('h:mm a').format(value)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedStart = value;
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
                            Flexible(
                              child: Text(
                                option.displayName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (option.isExternalLearner) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7CC),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Offline',
                                  style: TextStyle(
                                    color: Color(0xFF8A6500),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedLearnerId = value),
                hint: const Text('Select learner'),
              ),
              if (availableLearners.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'No learners are available for the selected duration at this time.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
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
                    final startsForDuration = _availableStartsForDuration;
                    if (!startsForDuration.any(
                      (start) => start.isAtSameMomentAs(_selectedStart),
                    )) {
                      _selectedStart = startsForDuration.isNotEmpty
                          ? startsForDuration.first
                          : widget.slotStart;
                    }
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
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.done,
                scrollPadding: const EdgeInsets.only(bottom: 180),
                onSubmitted: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Add lesson notes (optional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (widget.existing != null)
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pop(const _SlotDraftResult(remove: true));
                      },
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.error),
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
                    onPressed: _selectedLearnerId == null || !hasAvailableStart
                        ? null
                        : () {
                            final notes = _notesController.text.trim();
                            Navigator.of(context).pop(
                              _SlotDraftResult(
                                start: _selectedStart,
                                learnerId: _selectedLearnerId,
                                durationMinutes: _selectedDuration,
                                notes: notes,
                              ),
                            );
                          },
                    child: Text(widget.saveLabel),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotDraftResult {
  const _SlotDraftResult({
    this.start,
    this.learnerId,
    this.durationMinutes,
    this.remove = false,
    this.notes,
  });

  final DateTime? start;
  final String? learnerId;
  final int? durationMinutes;
  final bool remove;
  final String? notes;
}

class _CommittedSlotSheet extends StatelessWidget {
  const _CommittedSlotSheet({
    required this.slot,
    required this.onCancel,
    required this.onEdit,
  });

  final _ScheduledSlot slot;
  final VoidCallback onCancel;
  final VoidCallback onEdit;

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
              Text(
                _InstructorAvailabilityScreenState._formatDateTime(slot.start),
              ),
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onEdit();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.edit_calendar_rounded),
              label: const Text('Edit lesson'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onCancel();
                },
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel lesson'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoveSlotResult {
  const _MoveSlotResult({required this.start});

  final DateTime start;
}

class _MoveLessonSheet extends StatelessWidget {
  const _MoveLessonSheet({
    required this.learnerName,
    required this.currentStart,
    required this.candidateStarts,
  });

  final String learnerName;
  final DateTime currentStart;
  final List<DateTime> candidateStarts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
        left: 16,
        right: 16,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Move $learnerName',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Current slot: ${_InstructorAvailabilityScreenState._formatDateTime(currentStart)}',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 16),
          if (candidateStarts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'No open slots match this learner availability this week.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: candidateStarts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final start = candidateStarts[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available_rounded),
                    title: Text(DateFormat('EEE, MMM d').format(start)),
                    subtitle: Text(DateFormat('h:mm a').format(start)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(
                      context,
                    ).pop(_MoveSlotResult(start: start)),
                  );
                },
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
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
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
