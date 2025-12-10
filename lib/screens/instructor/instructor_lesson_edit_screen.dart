import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../services/supabase_service.dart';

class InstructorLessonEditScreen extends StatefulWidget {
  final Map<String, dynamic> lesson;

  const InstructorLessonEditScreen({super.key, required this.lesson});

  @override
  State<InstructorLessonEditScreen> createState() =>
      _InstructorLessonEditScreenState();
}

class _InstructorLessonEditScreenState
    extends State<InstructorLessonEditScreen> {
  late TextEditingController _focusController;
  late TextEditingController _pickupController;
  late TextEditingController _notesController;
  late TextEditingController _costController;

  late DateTime _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _saving = false;

  late String _name;
  late String _avatarUrl;
  Map<String, dynamic>? _instructorProfile;

  @override
  void initState() {
    super.initState();
    final lesson = widget.lesson;
    _name = _readName(lesson);
    _avatarUrl = _readAvatar(lesson);
    _focusController =
        TextEditingController(text: _deriveFocus(lesson, fallback: ''));
    _pickupController =
        TextEditingController(text: _deriveLocation(lesson, fallback: ''));
    _notesController =
        TextEditingController(text: (lesson['notes'] ?? '').toString());
    _costController = TextEditingController(
      text: _deriveCost(lesson),
    );

    _selectedDate = _readDate(lesson) ?? DateTime.now();
    _startTime = _readTime(lesson['start_time']) ??
        _timeFromDateString(lesson['scheduled_at']);
    _endTime = _readTime(lesson['end_time']);

    _loadInstructorProfile();
  }

  @override
  void dispose() {
    _focusController.dispose();
    _pickupController.dispose();
    _notesController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _loadInstructorProfile() async {
    final instructorId =
        (widget.lesson['instructor_id'] ?? SupabaseService.currentUser?.id)
            ?.toString();
    if (instructorId == null || instructorId.isEmpty) return;
    try {
      final profile =
          await SupabaseService.getInstructorProfileDetail(instructorId);
      if (!mounted || profile == null) return;
      setState(() {
        _instructorProfile = profile;
      });
      _prefillCost(profile);
    } catch (_) {
      // Ignore errors and leave fields as-is.
    }
  }

  String _readName(Map<String, dynamic> lesson) {
    final direct = (lesson['learner'] ?? lesson['learner_name'] ?? '')
        .toString()
        .trim();
    if (direct.isNotEmpty) return direct;
    final learner = lesson['learner'];
    if (learner is Map<String, dynamic>) {
      final first = (learner['first_name'] ?? '').toString().trim();
      final last = (learner['last_name'] ?? '').toString().trim();
      final combined = '$first $last'.trim();
      if (combined.isNotEmpty) return combined;
      final email = (learner['email'] ?? '').toString().trim();
      if (email.isNotEmpty) return email;
    }
    return 'Learner';
  }

  String _readAvatar(Map<String, dynamic> lesson) {
    String? pick(Map<String, dynamic>? source) {
      if (source == null) return null;
      final primary = (source['profile_image_url'] ?? source['avatar_url'])
          ?.toString()
          .trim();
      if (primary != null && primary.isNotEmpty) return primary;
      return null;
    }

    if (lesson['avatar_url'] is String) {
      final direct = (lesson['avatar_url'] as String).trim();
      if (direct.isNotEmpty) return direct;
    }
    if (lesson['learner'] is Map<String, dynamic>) {
      final fromLearner =
          pick(Map<String, dynamic>.from(lesson['learner'] as Map));
      if (fromLearner != null) return fromLearner;
    }
    if (lesson['learner_profile'] is Map<String, dynamic>) {
      final profile = Map<String, dynamic>.from(lesson['learner_profile'] as Map);
      final fromProfile = pick(profile);
      if (fromProfile != null) return fromProfile;
      if (profile['profile'] is Map) {
        final nested = Map<String, dynamic>.from(profile['profile'] as Map);
        final nestedPick = pick(nested);
        if (nestedPick != null) return nestedPick;
      }
    }
    return '';
  }

  DateTime? _readDate(Map<String, dynamic> lesson) {
    final raw = lesson['scheduled_at']?.toString();
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    return parsed?.toLocal();
  }

  TimeOfDay? _timeFromDateString(dynamic value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return null;
    final local = parsed.toLocal();
    return TimeOfDay(hour: local.hour, minute: local.minute);
  }

  TimeOfDay? _readTime(dynamic raw) {
    if (raw == null) return null;
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _deriveFocus(Map<String, dynamic> lesson, {required String fallback}) {
    final direct = (lesson['focus'] ?? lesson['learning_focus'] ?? '')
        .toString()
        .trim();
    if (direct.isNotEmpty) return direct;
    if (lesson['learner_profile'] is Map<String, dynamic>) {
      final profile = Map<String, dynamic>.from(lesson['learner_profile'] as Map);
      final focus = (profile['learning_focus'] ?? '').toString().trim();
      if (focus.isNotEmpty) return focus;
    }
    if (lesson['learner'] is Map<String, dynamic>) {
      final learner = Map<String, dynamic>.from(lesson['learner'] as Map);
      final focus = (learner['learning_focus'] ?? '').toString().trim();
      if (focus.isNotEmpty) return focus;
    }
    return fallback;
  }

  String _deriveLocation(Map<String, dynamic> lesson,
      {required String fallback}) {
    final direct = (lesson['pickup_location'] ??
            lesson['location'] ??
            lesson['meeting_location'] ??
            '')
        .toString()
        .trim();
    if (direct.isNotEmpty) return direct;

    List<dynamic>? preferredFrom(Map<String, dynamic>? src) {
      if (src == null) return null;
      final value = src['preferred_locations'];
      return value is List ? value : null;
    }

    List<dynamic>? preferred;
    if (lesson['learner'] is Map<String, dynamic>) {
      final learner = Map<String, dynamic>.from(lesson['learner'] as Map);
      preferred = preferredFrom(learner) ??
          preferredFrom(learner['profile'] is Map
              ? Map<String, dynamic>.from(learner['profile'] as Map)
              : null);
    }
    if (preferred == null && lesson['learner_profile'] is Map<String, dynamic>) {
      final profile = Map<String, dynamic>.from(lesson['learner_profile'] as Map);
      preferred = preferredFrom(profile) ??
          preferredFrom(profile['profile'] is Map
              ? Map<String, dynamic>.from(profile['profile'] as Map)
              : null);
    }
    if (preferred != null) {
      for (final entry in preferred) {
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
    }
    return fallback;
  }

  String _deriveCost(Map<String, dynamic> lesson) {
    final value = lesson['cost'];
    if (value is num) return value.toString();
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return '';
  }

  void _prefillCost(Map<String, dynamic> profile) {
    final focus = _focusController.text.trim().toLowerCase();
    final normalizedFocus = focus.replaceAll(RegExp(r'[^a-z0-9]'), '');

    double? asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    double? cost;
    final offeringRates = profile['offering_rates'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(profile['offering_rates'] as Map)
        : const <String, dynamic>{};
    if (normalizedFocus.isNotEmpty) {
      for (final entry in offeringRates.entries) {
        final key = entry.key.toString().toLowerCase().replaceAll(
              RegExp(r'[^a-z0-9]'),
              '',
            );
        if (key == normalizedFocus) {
          cost = asDouble(entry.value);
          break;
        }
      }
    }
    cost ??= asDouble(profile['default_rate']);
    if (cost != null && cost > 0) {
      _costController.text = cost.toStringAsFixed(2);
    }
  }

  String _formatTimeLabel(TimeOfDay? time) {
    if (time == null) return 'Select time';
    final dt = DateTime(0, 1, 1, time.hour, time.minute);
    return DateFormat.jm().format(dt);
  }

  String _formatDateLabel(DateTime date) =>
      DateFormat.yMMMMd().format(date.toLocal());

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? _startTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  String _to24h(TimeOfDay? time) {
    if (time == null) return '';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _save() async {
    if (_saving) return;
    final focus = _focusController.text.trim();
    final pickup = _pickupController.text.trim();
    final notes = _notesController.text.trim();
    final costRaw = _costController.text.trim();

    final start = _startTime;
    final end = _endTime;

    if (start == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a start time.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      DateTime scheduledAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        start.hour,
        start.minute,
      );

      final lessonId = widget.lesson['id']?.toString();
      if (lessonId == null || lessonId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lesson id is missing.')),
        );
        return;
      }

      double? cost;
      if (costRaw.isNotEmpty) {
        cost = double.tryParse(costRaw);
      }

      final updated = await SupabaseService.updateLessonDetails(
        lessonId: lessonId,
        scheduledAt: scheduledAt,
        lessonDate: _selectedDate,
        startTime: _to24h(start),
        endTime: end != null ? _to24h(end) : null,
        focus: focus.isNotEmpty ? focus : null,
        pickupLocation: pickup.isNotEmpty ? pickup : null,
        notes: notes.isNotEmpty ? notes : null,
        cost: cost,
      );

      if (!mounted) return;
      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save lesson changes.')),
        );
        return;
      }

      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving lesson: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit lesson'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ocean,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.ocean.withOpacity(0.12),
                backgroundImage:
                    _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                child: _avatarUrl.isEmpty
                    ? Text(
                        _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ocean,
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
                      _name,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateLabel(_selectedDate),
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _FieldGroup(
            label: 'Date & Time',
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickDate,
                    child: Text(_formatDateLabel(_selectedDate)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FieldGroup(
                  label: 'Start time',
                  child: OutlinedButton(
                    onPressed: _pickStartTime,
                    child: Text(_formatTimeLabel(_startTime)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FieldGroup(
                  label: 'End time (optional)',
                  child: OutlinedButton(
                    onPressed: _pickEndTime,
                    child: Text(_formatTimeLabel(_endTime)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FieldGroup(
            label: 'Session focus',
            child: TextField(
              controller: _focusController,
              decoration: const InputDecoration(
                hintText: 'e.g. G2 Test Prep',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _FieldGroup(
            label: 'Pickup location',
            child: TextField(
              controller: _pickupController,
              decoration: const InputDecoration(
                hintText: 'Enter pickup address',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _FieldGroup(
            label: 'Cost',
            child: TextField(
              controller: _costController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: 'e.g. 65.00',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _FieldGroup(
            label: 'Notes for the lesson',
            child: TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Add reminders or goals for this session',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldGroup extends StatelessWidget {
  final String label;
  final Widget child;

  const _FieldGroup({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.ocean,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
