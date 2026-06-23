import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/learner_progress.dart';
import '../../services/supabase_service.dart';
import '../../widgets/glass_panel.dart';

class InstructorLearnerRosterPreviewScreen extends StatefulWidget {
  const InstructorLearnerRosterPreviewScreen({
    super.key,
    this.learner,
    this.summary,
    this.availabilityLines,
    this.onViewProfile,
    this.onRemoveLearner,
    this.onMarkGraduated,
  });

  final Map<String, dynamic>? learner;
  final Map<String, dynamic>? summary;
  final List<String>? availabilityLines;
  final VoidCallback? onViewProfile;
  final Future<bool> Function(BuildContext context)? onRemoveLearner;
  final Future<bool> Function(BuildContext context)? onMarkGraduated;

  @override
  State<InstructorLearnerRosterPreviewScreen> createState() =>
      _InstructorLearnerRosterPreviewScreenState();
}

class _InstructorLearnerRosterPreviewScreenState
    extends State<InstructorLearnerRosterPreviewScreen> {
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

  late final Map<String, dynamic> _learner =
      Map<String, dynamic>.from(widget.learner ?? const {});
  late final Map<String, dynamic> _summary =
      Map<String, dynamic>.from(widget.summary ?? const {});
  String? _phone;
  bool _loadingPhone = false;
  bool _removing = false;
  bool _graduating = false;
  bool _loadingProgress = false;
  List<LearnerProgressSkill> _progressSkills = defaultLearnerProgressSkills();
  String? _progressSavingSkillId;

  @override
  void initState() {
    super.initState();
    final summaryPhone = _summary['phone'];
    if (summaryPhone is String && summaryPhone.trim().isNotEmpty) {
      _learner['phone'] ??= summaryPhone.trim();
    }
    _resolvePhone();
    _loadProgress();
  }

  Future<void> _resolvePhone() async {
    final existing = _extractPhoneFromMap();
    if (existing != null) {
      setState(() => _phone = existing);
      return;
    }
    final learnerId = _learnerId();
    if (learnerId == null) return;
    setState(() => _loadingPhone = true);
    final profile = await SupabaseService.getRawProfile(learnerId);
    if (!mounted) return;
    setState(() {
      _phone = _stringValue(profile?['phone']);
      _loadingPhone = false;
    });
  }

  String? _extractPhoneFromMap() {
    final profile = _learner['learner'] as Map?;
    final candidates = [
      _learner['phone'],
      profile?['phone'],
      _learner['requested_phone'],
      _learner['learner_phone'],
    ];
    for (final candidate in candidates) {
      final value = _stringValue(candidate);
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String? _learnerId() {
    final direct = _learner['learner_id'];
    if (direct != null) {
      return direct.toString();
    }
    final profile = _learner['learner'] as Map?;
    final embedded = profile?['id'];
    if (embedded != null) {
      return embedded.toString();
    }
    return null;
  }

  bool _isExternalLearner() {
    final value = _learner['is_external_learner'] ?? _learner['is_offline'];
    if (value == true) return true;
    return _learner['external_learner_id'] != null;
  }

  bool _isGraduated() {
    final profile = _learner['learner'] as Map?;
    final candidates = [
      _learner['status'],
      _learner['learning_status'],
      _learner['learner_status'],
      _learner['progress_status'],
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

  Future<void> _loadProgress() async {
    final learnerId = _learnerId();
    if (learnerId == null || _isExternalLearner()) return;
    setState(() => _loadingProgress = true);
    try {
      final rows = await SupabaseService.getLearnerSkillProgress(learnerId);
      if (!mounted) return;
      setState(() {
        _progressSkills = learnerProgressSkillsFromRows(rows);
        _loadingProgress = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProgress = false);
    }
  }

  String _name() {
    return (_summary['name'] as String?)?.trim().isNotEmpty == true
        ? (_summary['name'] as String)
        : 'Learner';
  }

  int? _age() {
    final age = _summary['age'];
    if (age is int) return age;
    return null;
  }

  String? _gender() {
    final gender = _summary['gender'];
    if (gender is String && gender.trim().isNotEmpty) {
      return gender;
    }
    return null;
  }

  String? _avatarUrl() {
    final avatar = _summary['avatarUrl'];
    return _stringValue(avatar);
  }

  Map<String, List<String>> _buildAvailabilityMap(
      Map<String, dynamic> learner) {
    final availability =
        learner['weekly_availability'] as Map<String, List<dynamic>>?;
    if (availability == null || availability.isEmpty) {
      return const {};
    }
    final normalized = <String, List<String>>{};
    for (final entry in availability.entries) {
      final day = entry.key.toString().toLowerCase();
      final slots = entry.value
          .whereType<String>()
          .map((slot) => slot.toLowerCase())
          .toList()
        ..sort(
          (a, b) => (_slotOrder[a] ?? 99).compareTo(_slotOrder[b] ?? 99),
        );
      normalized[day] = slots;
    }
    return normalized;
  }

  List<String> _buildAvailabilityLines(Map<String, dynamic> learner) {
    final availability = _buildAvailabilityMap(learner);
    if (availability.isEmpty) return const ['Availability not set.'];
    final keys = availability.keys.toList()
      ..sort((a, b) => _dayIndex(a).compareTo(_dayIndex(b)));
    return keys
        .map(
          (day) =>
              '${_capitalize(day)}: ${availability[day]!.map((slot) => _slotLabels[slot] ?? slot).join(', ')}',
        )
        .toList();
  }

  int _dayIndex(String day) {
    final index = _daySequence.indexOf(day);
    return index == -1 ? 99 : index;
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  String? _stringValue(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    return str.isEmpty ? null : str;
  }

  Future<void> _handleViewProfile() async {
    final callback = widget.onViewProfile;
    if (callback == null) return;
    if (mounted) {
      Navigator.of(context).pop();
    }
    callback();
  }

  Future<void> _handleRemove() async {
    final callback = widget.onRemoveLearner;
    if (callback == null || _removing) return;
    setState(() => _removing = true);
    final removed = await callback(context);
    if (!mounted) return;
    if (removed) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _removing = false);
  }

  Future<void> _handleGraduated() async {
    final callback = widget.onMarkGraduated;
    if (callback == null || _graduating) return;
    setState(() => _graduating = true);
    final graduated = await callback(context);
    if (!mounted) return;
    setState(() => _graduating = false);
    if (graduated) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _updateSkillProgress(
    LearnerProgressSkill skill,
    LearnerSkillStatus status,
  ) async {
    final learnerId = _learnerId();
    if (learnerId == null || _progressSavingSkillId != null) return;

    final previousSkills = List<LearnerProgressSkill>.from(_progressSkills);
    final now = DateTime.now().toUtc();
    setState(() {
      _progressSavingSkillId = skill.id;
      _progressSkills = _progressSkills.map((item) {
        if (item.id != skill.id) return item;
        return item.copyWith(
          status: status,
          completedAt: status.isTestReady ? now : null,
          updatedAt: now,
        );
      }).toList();
    });

    try {
      await SupabaseService.upsertLearnerSkillProgress(
        userId: learnerId,
        skillId: skill.id,
        status: status.storageValue,
        updatedByRole: 'instructor',
      );
      if (!mounted) return;
      setState(() => _progressSavingSkillId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${skill.name} set to ${status.label}.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _progressSkills = previousSkills;
        _progressSavingSkillId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update progress: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final demographics = _buildDemographics();
    final availabilityMap = _buildAvailabilityMap(_learner).entries.toList()
      ..sort((a, b) => _dayIndex(a.key).compareTo(_dayIndex(b.key)));
    final isGraduated = _isGraduated();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learner Details'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GlassPanel(
                        borderRadius: BorderRadius.circular(30),
                        opacity: 0.12,
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 36,
                              backgroundColor:
                                  AppColors.primaryBlue.withValues(alpha: 0.15),
                              backgroundImage: _avatarUrl() != null
                                  ? NetworkImage(_avatarUrl()!)
                                  : null,
                              child: _avatarUrl() == null
                                  ? Text(
                                      _name()[0].toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryBlue,
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
                                    _name(),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                  if (demographics != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      demographics,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      GlassPanel(
                        borderRadius: BorderRadius.circular(28),
                        opacity: 0.12,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Phone',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_loadingPhone)
                              const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              Text(
                                _phone ?? 'Phone not set',
                                style: const TextStyle(fontSize: 16),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      GlassPanel(
                        borderRadius: BorderRadius.circular(28),
                        opacity: 0.12,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Availability',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (availabilityMap.isEmpty)
                              const Text('Availability not set.')
                            else
                              Column(
                                children: availabilityMap
                                    .map(
                                      (entry) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: _AvailabilityPill(
                                          day: _capitalize(entry.key),
                                          slots: entry.value
                                              .map((slot) =>
                                                  _slotLabels[slot] ?? slot)
                                              .toList(),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildProgressPanel(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onMarkGraduated == null ||
                              _graduating ||
                              isGraduated
                          ? null
                          : _handleGraduated,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0B7A3B),
                        side: const BorderSide(
                          color: Color(0xFFB7E4C7),
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _graduating
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.school_outlined),
                      label: Text(
                        isGraduated
                            ? 'Graduated'
                            : _graduating
                                ? 'Graduating...'
                                : 'Mark Graduated',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 52) / 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: widget.onViewProfile == null
                          ? null
                          : _handleViewProfile,
                      icon: const Icon(Icons.person_outline),
                      label: const Text('View Profile'),
                    ),
                  ),
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 52) / 2,
                    child: OutlinedButton.icon(
                      onPressed: widget.onRemoveLearner == null || _removing
                          ? null
                          : _handleRemove,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(
                          color: AppColors.error,
                          width: 1.2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _removing
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.person_remove_alt_1_outlined),
                      label: Text(_removing ? 'Removing...' : 'Remove Learner'),
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

  Widget _buildProgressPanel() {
    if (_isExternalLearner()) {
      return GlassPanel(
        borderRadius: BorderRadius.circular(28),
        opacity: 0.12,
        padding: const EdgeInsets.all(20),
        child: const Text(
          'Progress tracking is available for app learners.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    final readyCount =
        _progressSkills.where((skill) => skill.status.isTestReady).length;
    final progress = _progressSkills.isEmpty
        ? 0.0
        : _progressSkills.fold<double>(
              0,
              (sum, skill) => sum + skill.status.score,
            ) /
            _progressSkills.length;

    return GlassPanel(
      borderRadius: BorderRadius.circular(28),
      opacity: 0.12,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progress & focus areas',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 12),
          if (_loadingProgress)
            const Center(child: CircularProgressIndicator())
          else ...[
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: progress.clamp(0, 1),
                    minHeight: 8,
                    backgroundColor: AppColors.grey200,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$readyCount/${_progressSkills.length} ready',
                  style: const TextStyle(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final skill in _progressSkills) ...[
              _ProgressSkillEditorTile(
                skill: skill,
                isSaving: _progressSavingSkillId == skill.id,
                onChanged: (status) => _updateSkillProgress(skill, status),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  String? _buildDemographics() {
    final age = _age();
    final gender = _gender();
    if (age != null && gender != null) {
      return '$age yrs • ${_capitalize(gender)}';
    }
    if (age != null) return '$age yrs';
    if (gender != null) return _capitalize(gender);
    return null;
  }
}

class _ProgressSkillEditorTile extends StatelessWidget {
  const _ProgressSkillEditorTile({
    required this.skill,
    required this.isSaving,
    required this.onChanged,
  });

  final LearnerProgressSkill skill;
  final bool isSaving;
  final ValueChanged<LearnerSkillStatus> onChanged;

  Color get _statusColor {
    switch (skill.status) {
      case LearnerSkillStatus.notStarted:
        return Colors.grey;
      case LearnerSkillStatus.practicing:
        return AppColors.info;
      case LearnerSkillStatus.confident:
        return AppColors.warning;
      case LearnerSkillStatus.testReady:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(skill.icon, color: _statusColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      skill.description,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isSaving)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<LearnerSkillStatus>(
            initialValue: skill.status,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: LearnerSkillStatus.values
                .map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(status.label),
                  ),
                )
                .toList(),
            onChanged: isSaving
                ? null
                : (status) {
                    if (status != null && status != skill.status) {
                      onChanged(status);
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({
    required this.day,
    required this.slots,
  });

  final String day;
  final List<String> slots;

  @override
  Widget build(BuildContext context) {
    final chipColor = AppColors.lightSurface.withOpacity(0.9);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      constraints: const BoxConstraints(minWidth: 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ocean,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: slots
                .map(
                  (slot) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.grey200),
                    ),
                    child: Text(
                      slot,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.lightOnSurface,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
