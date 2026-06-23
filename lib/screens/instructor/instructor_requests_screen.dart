import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_shadows.dart';
import '../../services/supabase_service.dart';
import '../../utils/learner_color_utils.dart';
import '../../utils/lesson_request_utils.dart';
import '../../widgets/glass_panel.dart';

BoxDecoration _outlinedSurfaceDecoration(double radius, {Color? color}) {
  return BoxDecoration(
    color: color ?? Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.border),
    boxShadow: AppShadows.subtle,
  );
}

class LearnerRosterView extends StatefulWidget {
  final EdgeInsetsGeometry padding;

  const LearnerRosterView({
    super.key,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  State<LearnerRosterView> createState() => _LearnerRosterViewState();
}

class _LearnerRosterViewState extends State<LearnerRosterView> {
  bool _loading = true;
  bool _error = false;
  List<Map<String, dynamic>> _learners = [];
  List<Map<String, dynamic>> _requests = [];
  final Set<String> _removingLearnerIds = <String>{};
  late final TextEditingController _searchController;
  String _searchQuery = '';
  String _learnerFilter = 'active';

  static const List<String> _daySequence = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  static const Map<String, int> _slotOrder = {
    'early': 0,
    'morning': 1,
    'afternoon': 2,
    'evening': 3,
  };

  static const Map<String, String> _slotLabels = {
    'early': 'Early (7am-9am)',
    'morning': 'Morning (9am-12pm)',
    'afternoon': 'Afternoon (12pm-4pm)',
    'evening': 'Evening (4pm-8pm)',
  };

  List<Map<String, dynamic>> get _filteredLearners {
    final filtered = _learners.where((learner) {
      switch (_learnerFilter) {
        case 'graduated':
          return _isGraduatedLearner(learner);
        case 'g2':
          return !_isGraduatedLearner(learner) && _licenseTier(learner) == 'g2';
        case 'g':
          return !_isGraduatedLearner(learner) && _licenseTier(learner) == 'g';
        case 'refresher':
          return !_isGraduatedLearner(learner) && _isRefresherLearner(learner);
        case 'offline':
          return !_isGraduatedLearner(learner) && _isExternalLearner(learner);
        default:
          return !_isGraduatedLearner(learner);
      }
    });
    if (_searchQuery.isEmpty) return filtered.toList();
    return filtered.where(_matchesSearch).toList();
  }

  int get _activeLearnerCount =>
      _learners.where((learner) => !_isGraduatedLearner(learner)).length;
  int get _graduatedCount =>
      _learners.where((learner) => _isGraduatedLearner(learner)).length;
  int get _g2Count =>
      _learners.where((learner) => _licenseTier(learner) == 'g2').length;
  int get _gCount =>
      _learners.where((learner) => _licenseTier(learner) == 'g').length;
  int get _refresherCount =>
      _learners.where((learner) => _isRefresherLearner(learner)).length;
  int get _offlineCount => _learners
      .where((learner) =>
          _isExternalLearner(learner) && !_isGraduatedLearner(learner))
      .length;

  void _selectLearnerFilter(String filter) {
    setState(() => _learnerFilter = filter);
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    _load();
  }

  Future<void> _load() async {
    final instructorId = SupabaseService.currentUser?.id;
    if (instructorId == null) {
      setState(() {
        _loading = false;
        _error = true;
        _learners = [];
        _requests = [];
        _removingLearnerIds.clear();
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = false;
      _removingLearnerIds.clear();
    });

    try {
      final results = await Future.wait([
        SupabaseService.getActiveLearnersWithAvailability(instructorId),
        SupabaseService.getLessonRequestsForInstructor(instructorId),
      ]);

      final learners = (results[0] as List<dynamic>)
          .whereType<Map<dynamic, dynamic>>()
          .map<Map<String, dynamic>>(
            (entry) => _prepareLearnerEntry(
              Map<String, dynamic>.from(
                entry.map((key, value) => MapEntry(key.toString(), value)),
              ),
            ),
          )
          .toList();

      final learnerIds = learners
          .where((learner) => !_isExternalLearner(learner))
          .map((learner) => _learnerId(learner))
          .whereType<String>()
          .toList();
      Map<String, int> progressCounts = {};
      Map<String, DateTime> nextLessons = {};
      if (learnerIds.isNotEmpty) {
        try {
          progressCounts =
              await SupabaseService.getLearnerProgressCounts(learnerIds);
          nextLessons = await SupabaseService.getNextLessonsForLearners(
            instructorId: instructorId,
            learnerIds: learnerIds,
          );
        } catch (_) {}
      }
      for (final learner in learners) {
        final id = _learnerId(learner);
        if (id == null) continue;
        learner['completed_skills'] = progressCounts[id] ?? 0;
        learner['total_skills'] = SupabaseService.learnerSkillCatalogSize;
        if (nextLessons.containsKey(id)) {
          learner['next_lesson_at'] = nextLessons[id];
        }
      }

      final requests = List<Map<String, dynamic>>.from(
              results[1] as List<dynamic>)
          .where((request) =>
              ((request['status'] as String?) ?? '').toLowerCase() == 'pending')
          .toList();

      if (!mounted) return;
      setState(() {
        _learners = learners;
        _requests = requests;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
        _learners = [];
        _requests = [];
        _removingLearnerIds.clear();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _load();

  Future<void> _showAddExternalLearnerSheet() async {
    final instructorId = SupabaseService.currentUser?.id;
    if (instructorId == null) return;

    final draft = await showModalBottomSheet<_ExternalLearnerDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _ExternalLearnerSheet(),
    );
    if (!mounted || draft == null) return;

    try {
      await SupabaseService.createExternalLearner(
        instructorId: instructorId,
        fullName: draft.fullName,
        phone: draft.phone,
        pickupAddress: draft.pickupAddress,
        learningFocus: draft.learningFocus,
        transmissionPreference: draft.transmissionPreference,
        notes: draft.notes,
        weeklyAvailability: Map<String, dynamic>.from(draft.weeklyAvailability),
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${draft.fullName} added to your roster.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to add offline learner: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showEditExternalLearnerSheet(
    Map<String, dynamic> learner,
  ) async {
    final instructorId = SupabaseService.currentUser?.id;
    final learnerId = _learnerId(learner);
    if (instructorId == null || learnerId == null) return;

    final draft = await showModalBottomSheet<_ExternalLearnerDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ExternalLearnerSheet(initialLearner: learner),
    );
    if (!mounted || draft == null) return;

    try {
      await SupabaseService.updateExternalLearner(
        instructorId: instructorId,
        externalLearnerId: learnerId,
        fullName: draft.fullName,
        phone: draft.phone,
        pickupAddress: draft.pickupAddress,
        transmissionPreference: draft.transmissionPreference,
        learningFocus: draft.learningFocus,
        notes: draft.notes,
        weeklyAvailability: Map<String, dynamic>.from(draft.weeklyAvailability),
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${draft.fullName} updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update offline learner: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<bool> _markLearnerGraduated(
    Map<String, dynamic> learner, {
    BuildContext? dialogContext,
  }) async {
    final instructorId = SupabaseService.currentUser?.id;
    final learnerId = _learnerId(learner);
    if (instructorId == null || learnerId == null) return false;

    final name = _learnerName(learner);
    final origin = dialogContext ?? context;
    final confirmed = await showDialog<bool>(
          context: origin,
          builder: (context) => AlertDialog(
            title: const Text('Mark as graduated?'),
            content: Text(
              '$name will move out of your active learner count. Any scheduled lessons that have not started will be cancelled.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Mark graduated'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return false;

    try {
      await SupabaseService.markLearnerGraduated(
        instructorId: instructorId,
        learnerId: learnerId,
        isExternalLearner: _isExternalLearner(learner),
      );
      await _load();
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name moved to graduated learners.')),
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to graduate $name: $error'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }
  }

  Map<String, dynamic> _prepareLearnerEntry(Map<String, dynamic> learner) {
    final learnerData = Map<String, dynamic>.from(learner);
    learnerData['weekly_availability'] = _normalizeAvailability(
        learnerData['weekly_availability'] ??
            learnerData['availability'] ??
            learnerData['availability_data']);
    final profile = Map<String, dynamic>.from(
        (learnerData['learner'] as Map?) ?? const <String, dynamic>{});

    void _setIfMissing(String key, dynamic value) {
      if (value == null) return;
      final existing = profile[key];
      if (existing == null || (existing is String && existing.trim().isEmpty)) {
        profile[key] = value;
      }
    }

    _setIfMissing('first_name', learnerData['requested_first_name']);
    _setIfMissing('last_name', learnerData['requested_last_name']);
    _setIfMissing('email', learnerData['requested_email']);
    _setIfMissing('profile_image_url', learnerData['requested_profile_url']);
    _setIfMissing('phone', learnerData['requested_phone']);

    if (profile.isNotEmpty) {
      learnerData['learner'] = profile;
      learnerData['phone'] ??= profile['phone'];
      learnerData['email'] ??= profile['email'];
    }
    learnerData['phone'] ??= learnerData['requested_phone'];

    return learnerData;
  }

  Map<String, List<String>> _normalizeAvailability(dynamic raw) {
    final result = <String, List<String>>{};
    if (raw is List) {
      for (final entry in raw.whereType<Map>()) {
        final dayRaw = entry['day'];
        final slotsRaw = entry['slots'];
        if (dayRaw == null) continue;
        final day = dayRaw.toString().toLowerCase();
        final slots = slotsRaw is List
            ? slotsRaw
                .whereType<String>()
                .map((slot) => slot.toLowerCase())
                .toList()
            : <String>[];
        if (slots.isEmpty) continue;
        slots.sort(
          (a, b) => (_slotOrder[a] ?? 99).compareTo(_slotOrder[b] ?? 99),
        );
        result[day] = slots;
      }
    } else if (raw is Map) {
      for (final entry in raw.entries) {
        final day = entry.key.toString().toLowerCase();
        final value = entry.value;
        final slots = value is List
            ? value
                .whereType<String>()
                .map((slot) => slot.toLowerCase())
                .toList()
            : <String>[];
        if (slots.isEmpty) continue;
        slots.sort(
          (a, b) => (_slotOrder[a] ?? 99).compareTo(_slotOrder[b] ?? 99),
        );
        result[day] = slots;
      }
    }
    return result;
  }

  int _dayIndex(String day) {
    final index = _daySequence.indexOf(day);
    return index == -1 ? 99 : index;
  }

  List<String> _availabilityLines(Map<String, dynamic> learner) {
    final availability =
        learner['weekly_availability'] as Map<String, List<String>>?;
    if (availability == null || availability.isEmpty) {
      return const ['Availability not set.'];
    }
    final days = availability.keys.toList()
      ..sort((a, b) => _dayIndex(a).compareTo(_dayIndex(b)));
    return days
        .map(
          (day) =>
              '${_capitalize(day)}: ${availability[day]!.map((slot) => _slotLabels[slot] ?? slot).join(', ')}',
        )
        .toList();
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  String _learnerName(Map<String, dynamic> learner) {
    final learnerProfile = learner['learner'] as Map?;
    final first = _stringValue(
          learnerProfile?['first_name'] ??
              learner['requested_first_name'] ??
              learner['first_name'],
        ) ??
        _stringValue(learner['requested_given_name']);
    final last = _stringValue(
      learnerProfile?['last_name'] ??
          learner['requested_last_name'] ??
          learner['last_name'],
    );
    final combined = [first, last].whereType<String>().join(' ').trim();
    if (combined.isNotEmpty) return combined;

    final fallbackName = _stringValue(learnerProfile?['name']) ??
        _stringValue(learner['requested_name']) ??
        _stringValue(learner['learner_name']);
    if (fallbackName != null) return fallbackName;

    final email = _learnerEmail(learner);
    if (email != null) return email;

    return formatLessonRequestLearnerName(learner);
  }

  String? _learnerId(Map<String, dynamic> learner) {
    return _stringValue(learner['learner_id']) ??
        _stringValue(learner['external_learner_id']) ??
        (learner['learner'] as Map?)?['id'] as String?;
  }

  bool _isExternalLearner(Map<String, dynamic> learner) {
    return learner['is_external_learner'] == true ||
        learner['is_offline'] == true ||
        _stringValue(learner['external_learner_id']) != null;
  }

  String _licenseTier(Map<String, dynamic> learner) {
    final profile = learner['learner'] as Map?;
    final candidates = [
      learner['learning_focus'],
      learner['requested_learning_focus'],
      profile?['learning_focus'],
      learner['license_class'],
      learner['licence_class'],
      profile?['license_class'],
      profile?['licence_class'],
      learner['learning_level'],
      learner['status'],
    ];
    for (final candidate in candidates) {
      final value = _stringValue(candidate);
      if (value != null) {
        final normalized = value.toLowerCase();
        if (normalized.contains('g2')) return 'g2';
        if (normalized.contains('g1')) return 'g1';
        if (normalized.contains('g')) return 'g';
      }
    }
    return 'other';
  }

  String? _licenseLabel(Map<String, dynamic> learner) {
    final tier = _licenseTier(learner);
    switch (tier) {
      case 'g2':
        return 'G2 Student';
      case 'g':
        return 'G Student';
      default:
        return null;
    }
  }

  String? _learningFocusLabel(Map<String, dynamic> learner) {
    final profile = learner['learner'] as Map?;
    final candidates = [
      learner['learning_focus'],
      learner['requested_learning_focus'],
      learner['focus'],
      learner['requested_focus'],
      profile?['learning_focus'],
    ];
    for (final candidate in candidates) {
      final value = _stringValue(candidate);
      if (value == null) continue;
      final normalized = value.toLowerCase();
      if (normalized.contains('g2')) {
        return normalized.contains('test') ? 'G2 Test' : 'G2';
      }
      if (normalized.contains('g')) {
        return normalized.contains('test') ? 'G Test' : 'G';
      }
    }
    return null;
  }

  bool _isGraduatedLearner(Map<String, dynamic> learner) {
    final profile = learner['learner'] as Map?;
    final candidates = [
      learner['status'],
      learner['learning_status'],
      learner['learner_status'],
      learner['progress_status'],
      profile?['status'],
    ];
    for (final candidate in candidates) {
      final value = _stringValue(candidate)?.toLowerCase();
      if (value == null) continue;
      if (value.contains('graduated') ||
          value.contains('completed') ||
          value.contains('passed')) {
        return true;
      }
    }
    return false;
  }

  bool _isRefresherLearner(Map<String, dynamic> learner) {
    final profile = learner['learner'] as Map?;
    final candidates = [
      learner['learning_focus'],
      learner['requested_learning_focus'],
      learner['focus'],
      learner['requested_focus'],
      profile?['learning_focus'],
    ];
    for (final candidate in candidates) {
      final value = _stringValue(candidate)?.toLowerCase();
      if (value == null) continue;
      if (value.contains('refresh')) return true;
    }
    return false;
  }

  double? _progressValue(Map<String, dynamic> learner) {
    final completed = _doubleValue(learner['completed_skills']) ??
        _doubleValue(learner['lessons_completed'] ??
            learner['completed_lessons'] ??
            learner['sessions_completed']);
    final target = _doubleValue(learner['total_skills']) ??
        _doubleValue(learner['lessons_target'] ??
            learner['goal_lessons'] ??
            learner['target_sessions']);
    if (target == null || target <= 0) return null;
    final ratio = (completed ?? 0) / target;
    if (ratio.isNaN) return null;
    return ratio.clamp(0, 1);
  }

  String? _progressSummary(Map<String, dynamic> learner) {
    final completedSkills = _doubleValue(learner['completed_skills']);
    final totalSkills = _doubleValue(learner['total_skills']);
    if (totalSkills != null && totalSkills > 0) {
      final comp = completedSkills ?? 0;
      return '${comp.toStringAsFixed(0)}/${totalSkills.toStringAsFixed(0)} skills';
    }
    final completedLessons = _doubleValue(learner['lessons_completed'] ??
        learner['completed_lessons'] ??
        learner['sessions_completed']);
    final lessonTarget = _doubleValue(learner['lessons_target'] ??
        learner['goal_lessons'] ??
        learner['target_sessions']);
    if (lessonTarget == null || lessonTarget <= 0) return null;
    return '${completedLessons?.toStringAsFixed(0) ?? '0'}/${lessonTarget.toStringAsFixed(0)} lessons';
  }

  double? _doubleValue(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String? _nextLessonLabel(Map<String, dynamic> learner) {
    final raw = learner['next_lesson_at'] ?? learner['next_lesson'];
    DateTime? date;
    if (raw is DateTime) {
      date = raw;
    } else if (raw is String) {
      date = DateTime.tryParse(raw);
    }
    if (date == null) return null;
    return DateFormat('MMM d').format(date.toLocal());
  }

  String _progressMetricLabel(Map<String, dynamic> learner) {
    final totalSkills = _doubleValue(learner['total_skills']);
    if (totalSkills != null && totalSkills > 0) {
      return 'Skills';
    }
    return 'Lessons';
  }

  String? _learnerEmail(Map<String, dynamic> learner) {
    return _stringValue((learner['learner'] as Map?)?['email']) ??
        _stringValue(learner['email']) ??
        _stringValue(learner['requested_email']) ??
        _stringValue(learner['learner_email']);
  }

  String? _learnerPhone(Map<String, dynamic> learner) {
    return _stringValue((learner['learner'] as Map?)?['phone']) ??
        _stringValue(learner['phone']) ??
        _stringValue(learner['learner_phone']);
  }

  LearnerColorSet _learnerColors(Map<String, dynamic> learner) {
    final profile = learner['learner'] as Map?;
    final key = _stringValue(learner['learner_id']) ??
        _stringValue(profile?['id']) ??
        _learnerEmail(learner) ??
        _learnerName(learner);
    return learnerColorForKey(key);
  }

  LearnerColorSet _requestColors(Map<String, dynamic> request) {
    final key = _stringValue(request['learner_id']) ??
        _stringValue(request['profile_id']) ??
        _stringValue(request['requested_email']) ??
        formatLessonRequestLearnerName(request);
    return learnerColorForKey(key);
  }

  bool _matchesSearch(Map<String, dynamic> learner) {
    if (_searchQuery.isEmpty) return true;
    final query = _searchQuery;
    final name = _learnerName(learner).toLowerCase();
    final phone = (_learnerPhone(learner) ?? '').toLowerCase();
    final license = (_licenseLabel(learner) ?? '').toLowerCase();
    return name.contains(query) ||
        phone.contains(query) ||
        license.contains(query);
  }

  String? _profileImageUrl(Map<String, dynamic> learner) {
    final profile = learner['learner'] as Map?;
    final candidates = [
      profile?['profile_image_url'],
      learner['requested_profile_url'],
      learner['requested_avatar_url'],
    ];
    for (final candidate in candidates) {
      final value = _stringValue(candidate);
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed);
    }
    return null;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return DateTime.tryParse(trimmed);
    }
    return null;
  }

  int? _deriveAge(Map<String, dynamic> learner) {
    final profile = learner['learner'] as Map?;
    final ageSources = [
      learner['age'],
      profile?['age'],
      learner['requested_age'],
    ];
    for (final source in ageSources) {
      final parsed = _parseInt(source);
      if (parsed != null) return parsed;
    }

    final birthSources = [
      learner['date_of_birth'],
      learner['dob'],
      profile?['date_of_birth'],
      profile?['dob'],
    ];
    for (final source in birthSources) {
      final birthDate = _parseDate(source);
      if (birthDate != null) {
        final now = DateTime.now();
        var age = now.year - birthDate.year;
        final hadBirthday = (now.month > birthDate.month) ||
            (now.month == birthDate.month && now.day >= birthDate.day);
        if (!hadBirthday) age -= 1;
        if (age >= 0) return age;
      }
    }
    return null;
  }

  String? _learnerGender(Map<String, dynamic> learner) {
    final profile = learner['learner'] as Map?;
    final candidates = [
      learner['gender'],
      profile?['gender'],
      learner['requested_gender'],
    ];
    for (final candidate in candidates) {
      final value = _stringValue(candidate);
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  void _openLearnerOverview(Map<String, dynamic> learner) {
    final availability = _availabilityLines(learner);
    final summary = {
      'name': _learnerName(learner),
      'phone': _learnerPhone(learner),
      'age': _deriveAge(learner),
      'gender': _learnerGender(learner),
      'avatarUrl': _profileImageUrl(learner),
      'isRecurring': _isRecurring(learner),
    };
    GoRouter.of(context).push(
      AppRoutes.instructorLearnerRosterPreview,
      extra: {
        'learner': learner,
        'availability': availability,
        'summary': summary,
        'onViewProfile': () => _openLearnerProfile(learner),
        'onRemoveLearner': (BuildContext origin) =>
            _removeLearner(learner, dialogContext: origin),
        'onMarkGraduated': (BuildContext origin) =>
            _markLearnerGraduated(learner, dialogContext: origin),
      },
    );
  }

  void _openLearnerProfile(Map<String, dynamic> learner) {
    if (_isExternalLearner(learner)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Offline learner details are managed from this roster.'),
        ),
      );
      return;
    }
    final learnerId = _learnerId(learner);
    if (learnerId == null) return;
    GoRouter.of(context).push(
      AppRoutes.instructorLearnerDetail,
      extra: {
        ...learner,
        'profile_id': learnerId,
        'id': learnerId,
        'name': _learnerName(learner),
        if (learner['status'] != null) 'status': learner['status'],
      },
    );
  }

  void _openRequest(Map<String, dynamic> request) async {
    final updated = await GoRouter.of(context).push<Map<String, dynamic>>(
      AppRoutes.reviewLearnerRequest,
      extra: request,
    );
    if (!mounted) return;
    if (updated != null) {
      _load();
    }
  }

  Future<bool> _removeLearner(
    Map<String, dynamic> learner, {
    BuildContext? dialogContext,
  }) async {
    final instructorId = SupabaseService.currentUser?.id;
    final learnerId = _learnerId(learner);
    if (instructorId == null || learnerId == null) return false;

    final name = _learnerName(learner);
    final confirmed = await showDialog<bool>(
          context: dialogContext ?? context,
          builder: (context) => AlertDialog(
            title: const Text('Remove learner?'),
            content: Text(
              'Removing $name will move them out of your active roster and cancel any scheduled lessons that have not started.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return false;

    setState(() {
      _removingLearnerIds.add(learnerId);
    });

    var removed = false;
    try {
      if (_isExternalLearner(learner)) {
        await SupabaseService.releaseExternalLearnerFromInstructor(
          instructorId: instructorId,
          externalLearnerId: learnerId,
        );
      } else {
        await SupabaseService.releaseLearnerFromInstructor(
          instructorId: instructorId,
          learnerId: learnerId,
        );
      }
      removed = true;
      if (!mounted) return true;
      await _load();
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name removed from active learners.'),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to remove $name: $error'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _removingLearnerIds.remove(learnerId);
        });
      }
    }

    return removed;
  }

  Future<void> _callLearner(Map<String, dynamic> learner) async {
    final phone = _learnerPhone(learner);
    if (phone == null || phone.isEmpty) return;
    final normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri =
        Uri(scheme: 'tel', path: normalized.isEmpty ? phone : normalized);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String? _stringValue(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration:
                _outlinedSurfaceDecoration(28, color: Colors.transparent),
            child: GlassPanel(
              borderRadius: BorderRadius.circular(28),
              opacity: 0.12,
              borderColor: AppColors.border,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off,
                    size: 48,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Unable to load learners',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
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
                    onPressed: _load,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final learners = _filteredLearners;

    return RefreshIndicator(
      color: AppColors.primaryBlue,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        children: [
          _buildSummaryCards(),
          const SizedBox(height: 16),
          _buildAddOfflineLearnerButton(),
          const SizedBox(height: 12),
          _buildSearchField(),
          const SizedBox(height: 20),
          if (learners.isEmpty)
            _buildEmptyLearners()
          else
            ...learners.map(_buildLearnerCard),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 18.0;
        final width = constraints.maxWidth;
        final topCardWidth = (width - spacing) / 2;
        final bottomCardWidth = (width - (spacing * 2)) / 3;

        return Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: topCardWidth,
                  child: _LearnerHeroStatCard(
                    label: 'ACTIVE',
                    value: _activeLearnerCount.toString(),
                    icon: Icons.radio_button_checked_rounded,
                    iconColor: Colors.white,
                    iconBackground: const Color(0x3DFFFFFF),
                    backgroundColor: const Color(0xFF1E53D5),
                    borderColor: const Color(0xFF1E53D5),
                    valueColor: Colors.white,
                    labelColor: const Color(0xFFDCE6FF),
                    iconRingColor: const Color(0xFF79A1FF),
                    selected: _learnerFilter == 'active',
                    onTap: () => _selectLearnerFilter('active'),
                  ),
                ),
                const SizedBox(width: spacing),
                SizedBox(
                  width: topCardWidth,
                  child: _LearnerHeroStatCard(
                    label: 'GRADUATED',
                    value: _graduatedCount.toString(),
                    icon: Icons.check_rounded,
                    iconColor: Colors.white,
                    iconBackground: Colors.black,
                    backgroundColor: Colors.white,
                    borderColor: const Color(0xFFDADFE8),
                    valueColor: const Color(0xFF111827),
                    labelColor: const Color(0xFF6B7280),
                    iconRingColor: const Color(0xFFFFF0B8),
                    shadowColor: const Color(0x140F172A),
                    selected: _learnerFilter == 'graduated',
                    onTap: () => _selectLearnerFilter('graduated'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: spacing),
            Row(
              children: [
                SizedBox(
                  width: bottomCardWidth,
                  child: _LearnerMiniStatCard(
                    label: 'G2',
                    value: _g2Count.toString(),
                    backgroundColor: const Color(0xFFF2F5FF),
                    borderColor: const Color(0xFFD8E2FF),
                    labelColor: const Color(0xFF1E53D5),
                    valueColor: const Color(0xFF1E53D5),
                    selected: _learnerFilter == 'g2',
                    onTap: () => _selectLearnerFilter('g2'),
                  ),
                ),
                const SizedBox(width: spacing),
                SizedBox(
                  width: bottomCardWidth,
                  child: _LearnerMiniStatCard(
                    label: 'G',
                    value: _gCount.toString(),
                    backgroundColor: const Color(0xFFFFFBE8),
                    borderColor: const Color(0xFFF7E6A1),
                    labelColor: Colors.black,
                    valueColor: Colors.black,
                    selected: _learnerFilter == 'g',
                    onTap: () => _selectLearnerFilter('g'),
                  ),
                ),
                const SizedBox(width: spacing),
                SizedBox(
                  width: bottomCardWidth,
                  child: _LearnerMiniStatCard(
                    label: 'REFRESHER',
                    value: _refresherCount.toString(),
                    backgroundColor: Colors.white,
                    borderColor: const Color(0xFFDADFE8),
                    labelColor: const Color(0xFF6B7280),
                    valueColor: const Color(0xFF111827),
                    selected: _learnerFilter == 'refresher',
                    onTap: () => _selectLearnerFilter('refresher'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                avatar: const Icon(Icons.person_off_outlined, size: 18),
                label: Text('Offline learners ($_offlineCount)'),
                selected: _learnerFilter == 'offline',
                onSelected: (_) => _selectLearnerFilter('offline'),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: _outlinedSurfaceDecoration(18),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search learners',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide:
                const BorderSide(color: AppColors.primaryBlue, width: 1.6),
          ),
        ),
      ),
    );
  }

  Widget _buildAddOfflineLearnerButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showAddExternalLearnerSheet,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add offline learner'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyLearners() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _outlinedSurfaceDecoration(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.people_outline,
            size: 36,
            color: AppColors.primaryBlue,
          ),
          const SizedBox(height: 12),
          const Text(
            'No active learners yet.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Learners who connect through the app and offline learners you add will appear here.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _showAddExternalLearnerSheet,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Add offline learner'),
          ),
        ],
      ),
    );
  }

  Widget _buildLearnerCard(Map<String, dynamic> learner) {
    final colors = _learnerColors(learner);
    final name = _learnerName(learner);
    final phone = _learnerPhone(learner);
    final age = _deriveAge(learner);
    final gender = _learnerGender(learner);
    final avatarUrl = _profileImageUrl(learner);
    final demographics = [
      if (age != null) '$age yrs',
      if (gender != null) _capitalize(gender),
    ].join(' • ');
    final nextLesson = _nextLessonLabel(learner);
    final isExternal = _isExternalLearner(learner);
    final isGraduated = _isGraduatedLearner(learner);
    final nextLessonLabel =
        nextLesson != null ? 'Next: $nextLesson' : 'Next: TBD';
    final learnerId = _learnerId(learner);
    final focusLabel = _learningFocusLabel(learner);
    final isRemoving =
        learnerId != null && _removingLearnerIds.contains(learnerId);

    return Opacity(
      opacity: isRemoving ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border),
          boxShadow: AppShadows.subtle,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colors.surfaceStrong,
                  backgroundImage:
                      avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: colors.accentText,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: colors.accentText,
                              ),
                            ),
                          ),
                          if (isExternal) ...[
                            const SizedBox(width: 8),
                            const _FocusBadge(
                              label: 'Offline',
                              backgroundColor: Color(0xFFFFF7CC),
                              foregroundColor: Color(0xFF8A6500),
                            ),
                          ],
                          if (isGraduated) ...[
                            const SizedBox(width: 8),
                            const _FocusBadge(
                              label: 'Graduated',
                              backgroundColor: Color(0xFFE7F8EF),
                              foregroundColor: Color(0xFF0B7A3B),
                            ),
                          ],
                        ],
                      ),
                      if (demographics.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          demographics,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.accentText.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (isRemoving)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                    ),
                  )
                else if (focusLabel != null)
                  _FocusBadge(
                    label: focusLabel,
                    backgroundColor: colors.pillBackground,
                    foregroundColor: colors.accent,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InlineInfo(
                    icon: Icons.calendar_today_outlined,
                    value: nextLessonLabel,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InlineInfo(
                    icon: isExternal
                        ? Icons.person_off_outlined
                        : Icons.verified_user_outlined,
                    value: isExternal ? 'Offline learner' : 'App learner',
                    color: colors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 20, color: colors.border),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isRemoving || phone == null
                        ? null
                        : () => _callLearner(learner),
                    icon: const Icon(Icons.phone),
                    label: Text(
                      phone == null || phone.isEmpty
                          ? 'Contact'
                          : 'Contact • $phone',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.accent,
                      side: BorderSide(
                        color: colors.border,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        isRemoving ? null : () => _openLearnerOverview(learner),
                    icon: const Icon(Icons.person_search_outlined),
                    label: const Text('View Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.accent,
                      side: BorderSide(
                        color: colors.border,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (isExternal) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: isRemoving
                    ? null
                    : () => _showEditExternalLearnerSheet(learner),
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Edit availability'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.accent,
                  side: BorderSide(color: colors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isRecurring(Map<String, dynamic> learner) {
    final status = _stringValue(learner['status']);
    if (status == null) return false;
    return status.toLowerCase().contains('recurring');
  }
}

class _ExternalLearnerDraft {
  const _ExternalLearnerDraft({
    required this.fullName,
    required this.weeklyAvailability,
    this.phone,
    this.pickupAddress,
    this.learningFocus,
    this.transmissionPreference,
    this.notes,
  });

  final String fullName;
  final String? phone;
  final String? pickupAddress;
  final String? learningFocus;
  final String? transmissionPreference;
  final String? notes;
  final Map<String, List<String>> weeklyAvailability;
}

class _ExternalLearnerSheet extends StatefulWidget {
  const _ExternalLearnerSheet({this.initialLearner});

  final Map<String, dynamic>? initialLearner;

  @override
  State<_ExternalLearnerSheet> createState() => _ExternalLearnerSheetState();
}

class _ExternalLearnerSheetState extends State<_ExternalLearnerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pickupController = TextEditingController();
  final _notesController = TextEditingController();
  final Map<String, Set<String>> _availability = {};
  String? _focus;
  String? _transmission;

  static const List<String> _days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  static const Map<String, String> _dayLabels = {
    'monday': 'Mon',
    'tuesday': 'Tue',
    'wednesday': 'Wed',
    'thursday': 'Thu',
    'friday': 'Fri',
    'saturday': 'Sat',
    'sunday': 'Sun',
  };

  static const Map<String, String> _slotLabels = {
    'early': 'Early',
    'morning': 'Morning',
    'afternoon': 'Afternoon',
    'evening': 'Evening',
  };

  bool get _isEditing => widget.initialLearner != null;

  @override
  void initState() {
    super.initState();
    final learner = widget.initialLearner;
    if (learner == null) return;
    _nameController.text = _stringValue(learner['learner_name']) ??
        _stringValue((learner['learner'] as Map?)?['name']) ??
        '';
    _phoneController.text = _stringValue(learner['phone']) ??
        _stringValue((learner['learner'] as Map?)?['phone']) ??
        '';
    final preferredLocations = learner['preferred_locations'];
    if (preferredLocations is List && preferredLocations.isNotEmpty) {
      final first = preferredLocations.first;
      if (first is Map) {
        _pickupController.text = _stringValue(first['address']) ??
            _stringValue(first['label']) ??
            '';
      }
    }
    _notesController.text = _stringValue(learner['notes']) ?? '';
    _focus = _stringValue(learner['learning_focus']);
    _transmission = _stringValue(learner['transmission_preference']) ??
        _stringValue((learner['learner'] as Map?)?['transmission_preference']);
    _seedAvailability(learner['weekly_availability']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _pickupController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _clean(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _stringValue(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  void _seedAvailability(dynamic raw) {
    if (raw is! Map) return;
    for (final entry in raw.entries) {
      final day = entry.key.toString();
      if (!_days.contains(day)) continue;
      final values = entry.value;
      final slots = <String>{};
      if (values is Iterable) {
        for (final value in values) {
          final slot = value.toString();
          if (_slotLabels.containsKey(slot)) slots.add(slot);
        }
      } else if (values is String && _slotLabels.containsKey(values)) {
        slots.add(values);
      }
      if (slots.isNotEmpty) {
        _availability[day] = slots;
      }
    }
  }

  void _toggleAvailability(String day, String slot) {
    setState(() {
      final slots = _availability.putIfAbsent(day, () => <String>{});
      if (slots.contains(slot)) {
        slots.remove(slot);
      } else {
        slots.add(slot);
      }
      if (slots.isEmpty) {
        _availability.remove(day);
      }
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _ExternalLearnerDraft(
        fullName: _nameController.text.trim(),
        phone: _clean(_phoneController.text),
        pickupAddress: _clean(_pickupController.text),
        learningFocus: _focus,
        transmissionPreference: _transmission,
        notes: _clean(_notesController.text),
        weeklyAvailability: _availability.map(
          (day, slots) => MapEntry(day, slots.toList()..sort()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _isEditing
                          ? 'Edit offline learner'
                          : 'Add offline learner',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _isEditing
                    ? 'Update contact details and availability for this offline learner.'
                    : 'Use this for learners you manage directly outside the app.',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Enter the learner name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number optional',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pickupController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Pickup address optional',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _focus,
                decoration: const InputDecoration(
                  labelText: 'Lesson focus optional',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'G2', child: Text('G2')),
                  DropdownMenuItem(value: 'G', child: Text('G')),
                  DropdownMenuItem(
                    value: 'Refresher',
                    child: Text('Refresher'),
                  ),
                ],
                onChanged: (value) => setState(() => _focus = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _transmission,
                decoration: const InputDecoration(
                  labelText: 'Car transmission',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'automatic',
                    child: Text('Automatic'),
                  ),
                  DropdownMenuItem(
                    value: 'manual',
                    child: Text('Manual'),
                  ),
                ],
                onChanged: (value) => setState(() => _transmission = value),
              ),
              const SizedBox(height: 16),
              const Text(
                'Availability optional',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'If this is empty, you can still book them manually in the planner.',
                style: TextStyle(color: Colors.black54, fontSize: 12),
              ),
              const SizedBox(height: 10),
              ..._days.map(_buildDayAvailability),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Notes optional',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(_isEditing ? 'Save changes' : 'Add learner'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayAvailability(String day) {
    final selected = _availability[day] ?? const <String>{};
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dayLabels[day] ?? day,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _slotLabels.entries.map((entry) {
              final isSelected = selected.contains(entry.key);
              return FilterChip(
                label: Text(entry.value),
                selected: isSelected,
                onSelected: (_) => _toggleAvailability(day, entry.key),
                selectedColor: const Color(0xFFEAF1FF),
                checkmarkColor: AppColors.primaryBlue,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primaryBlue : Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _LearnerHeroStatCard extends StatelessWidget {
  const _LearnerHeroStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.backgroundColor,
    required this.borderColor,
    required this.valueColor,
    required this.labelColor,
    required this.iconRingColor,
    this.shadowColor = const Color(0x180F172A),
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final Color backgroundColor;
  final Color borderColor;
  final Color valueColor;
  final Color labelColor;
  final Color iconRingColor;
  final Color shadowColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(34),
      child: Container(
        height: 228,
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(34),
          border: Border.all(
            color: selected ? AppColors.accent : borderColor,
            width: selected ? 3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: iconRingColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 42,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LearnerMiniStatCard extends StatelessWidget {
  const _LearnerMiniStatCard({
    required this.label,
    required this.value,
    required this.backgroundColor,
    required this.borderColor,
    required this.labelColor,
    required this.valueColor,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color backgroundColor;
  final Color borderColor;
  final Color labelColor;
  final Color valueColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 106,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : borderColor,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _FocusBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _InlineInfo({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _InfoLine({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
