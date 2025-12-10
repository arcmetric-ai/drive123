import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../utils/lesson_request_utils.dart';
import '../../widgets/glass_panel.dart';

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
    if (_searchQuery.isEmpty) return _learners;
    return _learners.where(_matchesSearch).toList();
  }

  int get _activeLearnerCount => _learners.length;
  int get _g2Count =>
      _learners.where((learner) => _licenseTier(learner) == 'g2').length;
  int get _gCount =>
      _learners.where((learner) => _licenseTier(learner) == 'g').length;

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
    return learner['learner_id'] as String? ??
        (learner['learner'] as Map?)?['id'] as String?;
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
      },
    );
  }

  void _openLearnerProfile(Map<String, dynamic> learner) {
    final learnerId = _learnerId(learner);
    if (learnerId == null) return;
    GoRouter.of(context).push(
      AppRoutes.instructorLearnerDetail,
      extra: {
        'profile_id': learnerId,
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
      await SupabaseService.releaseLearnerFromInstructor(
        instructorId: instructorId,
        learnerId: learnerId,
      );
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
          child: GlassPanel(
            borderRadius: BorderRadius.circular(28),
            opacity: 0.12,
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
          _buildHeader(),
          const SizedBox(height: 16),
          _buildSearchField(),
          const SizedBox(height: 16),
          _buildStatsRow(),
          const SizedBox(height: 20),
          if (learners.isEmpty)
            _buildEmptyLearners()
          else
            ...learners.map(_buildLearnerCard),
          const SizedBox(height: 32),
          _buildPendingSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.primaryBlue,
            Color(0xFF6DB7FF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'My Learners',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Manage your active learners and stay on top of upcoming lessons.',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search learners',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Active',
            value: _activeLearnerCount.toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'G2',
            value: _g2Count.toString(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'G',
            value: _gCount.toString(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyLearners() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.people_outline, size: 36, color: AppColors.primaryBlue),
          SizedBox(height: 12),
          Text(
            'No active learners yet.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlue,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Once a learner connects with you, their info and availability will appear here.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pending Learner Requests',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(height: 16),
        if (_requests.isEmpty)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.mail_outline,
                    size: 32, color: AppColors.primaryBlue),
                SizedBox(height: 12),
                Text(
                  'No requests right now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'When a learner reaches out, you can review and accept them from here.',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          )
        else
          ..._requests.map(_buildRequestCard),
      ],
    );
  }

  Widget _buildLearnerCard(Map<String, dynamic> learner) {
    final name = _learnerName(learner);
    final phone = _learnerPhone(learner);
    final age = _deriveAge(learner);
    final gender = _learnerGender(learner);
    final avatarUrl = _profileImageUrl(learner);
    final demographics = [
      if (age != null) '$age yrs',
      if (gender != null) _capitalize(gender),
    ].join(' • ');
    final progress = _progressValue(learner);
    final progressSummary = _progressSummary(learner);
    final nextLesson = _nextLessonLabel(learner);
    final progressLabel =
        progress != null ? '${(progress * 100).round()}%' : 'Tracking soon';
    final lessonsLabel = progressSummary ?? 'No stats yet';
    final nextLessonLabel = nextLesson != null ? 'Next: $nextLesson' : 'Next: TBD';
    final learnerId = _learnerId(learner);
    final focusLabel = _learningFocusLabel(learner);
    final isRemoving =
        learnerId != null && _removingLearnerIds.contains(learnerId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primaryBlue.withOpacity(0.12),
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (focusLabel != null) ...[
                      const SizedBox(height: 6),
                      _FocusBadge(label: focusLabel),
                    ],
                    if (demographics.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        demographics,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _openLearnerOverview(learner),
                icon: const Icon(Icons.chevron_right),
                color: Colors.black45,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.trending_up,
                  size: 18, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              const Text(
                'Progress',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                progressLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress ?? 0,
              minHeight: 6,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryBlue),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InlineInfo(
                  icon: Icons.menu_book_outlined,
                  value: lessonsLabel,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InlineInfo(
                  icon: Icons.calendar_today_outlined,
                  value: nextLessonLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 32),
          const SizedBox(height: 12),
          _InfoLine(
            icon: Icons.phone_outlined,
            value: phone ?? 'Phone not set',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: phone == null ? null : () => _callLearner(learner),
                  icon: const Icon(Icons.phone),
                  label: const Text('Contact'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: BorderSide(
                      color: AppColors.primaryBlue.withOpacity(0.35),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openLearnerOverview(learner),
                  icon: const Icon(Icons.person_search_outlined),
                  label: const Text('View Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                    side: BorderSide(
                      color: AppColors.primaryBlue.withOpacity(0.35),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isRecurring(Map<String, dynamic> learner) {
    final status = _stringValue(learner['status']);
    if (status == null) return false;
    return status.toLowerCase().contains('recurring');
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final name = formatLessonRequestLearnerName(request);
    final focus = (request['focus'] ?? request['message'] ?? '').toString();
    final createdAtRaw = request['created_at'];
    DateTime? createdAt;
    if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw);
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openRequest(request),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primaryBlue.withOpacity(0.12),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (focus.isNotEmpty)
                    Text(
                      focus,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  if (createdAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Requested on ${DateFormat('MMM d, yyyy - h:mm a').format(createdAt.toLocal())}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _FocusBadge extends StatelessWidget {
  final String label;

  const _FocusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryBlue,
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

  const _InlineInfo({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
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

  const _InfoLine({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryBlue),
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
