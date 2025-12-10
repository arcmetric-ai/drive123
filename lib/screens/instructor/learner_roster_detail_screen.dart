import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
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
  });

  final Map<String, dynamic>? learner;
  final Map<String, dynamic>? summary;
  final List<String>? availabilityLines;
  final VoidCallback? onViewProfile;
  final Future<bool> Function(BuildContext context)? onRemoveLearner;

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

  @override
  void initState() {
    super.initState();
    final summaryPhone = _summary['phone'];
    if (summaryPhone is String && summaryPhone.trim().isNotEmpty) {
      _learner['phone'] ??= summaryPhone.trim();
    }
    _resolvePhone();
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

  Map<String, List<String>> _buildAvailabilityMap(Map<String, dynamic> learner) {
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

  @override
  Widget build(BuildContext context) {
    final demographics = _buildDemographics();
    final availabilityMap = _buildAvailabilityMap(_learner).entries.toList()
      ..sort((a, b) => _dayIndex(a.key).compareTo(_dayIndex(b.key)));
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
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
                  const SizedBox(width: 12),
                  Expanded(
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
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
