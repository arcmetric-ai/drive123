import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../models/lesson_model.dart';
import '../../services/supabase_service.dart';

class InstructorLessonDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? lesson;

  const InstructorLessonDetailScreen({super.key, this.lesson});

  @override
  State<InstructorLessonDetailScreen> createState() =>
      _InstructorLessonDetailScreenState();
}

class _InstructorLessonDetailScreenState
    extends State<InstructorLessonDetailScreen> {
  late Map<String, dynamic> _lessonData;
  late Map<String, dynamic> _rawLesson;
  late TextEditingController _focusController;
  late TextEditingController _locationController;
  late TextEditingController _notesController;
  late TextEditingController _costController;
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rawLesson = widget.lesson ?? const <String, dynamic>{};
    _lessonData = _normalizeLessonData(_rawLesson.isNotEmpty
        ? _rawLesson
        : const <String, dynamic>{
            'learner': 'Alice Lee',
            'time': 'Mon, Oct 14 - 09:30 - 11:00',
            'focus': 'G2 practice - downtown intersections',
            'location': 'Union Station, Front St',
            'pickup': 'Learner provided vehicle',
            'notes':
                'Work on left turns at busy junctions. Review mirror checks.',
            'status': 'Scheduled',
            'learner_email': 'learner@example.com',
          });
    _focusController = TextEditingController();
    _locationController = TextEditingController();
    _notesController = TextEditingController();
    _costController = TextEditingController();
    _syncEditControllers();
  }

  @override
  void dispose() {
    _focusController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _syncEditControllers() {
    _focusController.text = (_lessonData['focus'] ?? '').toString();
    _locationController.text = (_lessonData['location'] ?? '').toString();
    _notesController.text = (_lessonData['notes'] ?? '').toString();
    _costController.text = _firstNonEmpty([_rawLesson['cost']]) ?? '';
    _selectedDate = _readScheduledDate(_rawLesson);
    _startTime = _parseTime(_rawLesson['start_time']) ??
        _timeFromScheduledAt(_rawLesson['scheduled_at']);
    _endTime = _parseTime(_rawLesson['end_time']);
  }

  static DateTime? _readScheduledDate(Map<String, dynamic> raw) {
    final scheduled = raw['scheduled_at']?.toString();
    if (scheduled != null && scheduled.trim().isNotEmpty) {
      return DateTime.tryParse(scheduled)?.toLocal();
    }
    final date = raw['lesson_date']?.toString();
    if (date != null && date.trim().isNotEmpty) {
      return DateTime.tryParse(date)?.toLocal();
    }
    return null;
  }

  static TimeOfDay? _timeFromScheduledAt(dynamic value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return null;
    final local = parsed.toLocal();
    return TimeOfDay(hour: local.hour, minute: local.minute);
  }

  static Map<String, dynamic> _normalizeLessonData(Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);

    final learnerName = _buildLearnerName(raw);
    final learnerEmail = _extractLearnerEmail(raw);
    final avatarUrl = _extractAvatarUrl(raw);
    data['learner'] = learnerName;
    if (learnerEmail != null && learnerEmail.isNotEmpty) {
      data['learner_email'] = learnerEmail;
    } else {
      data.remove('learner_email');
    }
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      data['avatar_url'] = avatarUrl;
    }

    data['status'] = _formatStatus(_deriveStatus(raw));
    data['focus'] = _deriveFocus(raw);
    data['location'] = _deriveLocation(raw);
    data['pickup'] = _firstNonEmpty([
          raw['pickup'],
          raw['pickup_location'],
          raw['pickup_note'],
          raw['vehicle'],
          raw['vehicle_preference'],
        ]) ??
        'Not specified';
    final notes = _firstNonEmpty([
      raw['notes'],
      raw['message'],
      raw['learner_notes'],
      raw['additional_notes'],
      raw['extra_details'],
    ]);
    if (notes != null) {
      data['notes'] = notes;
    } else {
      data.remove('notes');
    }
    data['time'] = _resolveTimeLabel(raw);

    return data;
  }

  static String _deriveFocus(Map<String, dynamic> raw) {
    final direct = _firstNonEmpty(
        [raw['focus'], raw['focus_area'], raw['goal'], raw['reason']]);
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();

    final profileFocus = () {
      final profile = raw['learner_profile'];
      if (profile is Map<String, dynamic>) {
        final focus = (profile['learning_focus'] ?? '').toString().trim();
        if (focus.isNotEmpty) return focus;
        if (profile['profile'] is Map) {
          final nested = Map<String, dynamic>.from(profile['profile'] as Map);
          final nestedFocus =
              (nested['learning_focus'] ?? '').toString().trim();
          if (nestedFocus.isNotEmpty) return nestedFocus;
        }
      }
      final learner = raw['learner'];
      if (learner is Map<String, dynamic>) {
        final focus = (learner['learning_focus'] ?? '').toString().trim();
        if (focus.isNotEmpty) return focus;
      }
      return '';
    }();

    if (profileFocus.isNotEmpty) return profileFocus;
    return 'Driving lesson';
  }

  static LessonStatus _deriveStatus(Map<String, dynamic> raw) {
    DateTime? scheduledDate;
    final scheduledRaw = raw['scheduled_at']?.toString();
    if (scheduledRaw != null) {
      scheduledDate = DateTime.tryParse(scheduledRaw)?.toLocal();
    }
    scheduledDate ??= raw['lesson_date'] is String
        ? DateTime.tryParse(raw['lesson_date'] as String)?.toLocal()
        : null;

    final fallbackStatus = LessonModel.parseStatus(
        (_firstNonEmpty([raw['status'], raw['request_status']]) ?? 'scheduled')
            .toString());

    if (scheduledDate == null) return fallbackStatus;

    double? durationHours;
    final hours = raw['duration_hours'];
    if (hours is num) {
      durationHours = hours.toDouble();
    } else if (raw['duration_minutes'] is num) {
      durationHours = (raw['duration_minutes'] as num).toDouble() / 60.0;
    }

    return LessonModel.deriveStatus(
      scheduledDate: scheduledDate,
      startTime: (raw['start_time'] ?? '').toString(),
      endTime: (raw['end_time'] ?? '').toString(),
      durationHours: durationHours,
      fallbackStatus: fallbackStatus,
    );
  }

  static String _formatStatus(LessonStatus status) {
    final name = status.name.replaceAll('_', ' ');
    if (name.isEmpty) return 'Scheduled';
    return name[0].toUpperCase() + name.substring(1);
  }

  static String _buildLearnerName(Map<String, dynamic> raw) {
    final direct =
        _firstNonEmpty([raw['learner'], raw['learner_name'], raw['name']]);
    if (direct != null) {
      return direct;
    }

    final learner = raw['learner'];
    if (learner is Map<String, dynamic>) {
      final first = _stringFrom(learner['first_name'])?.trim() ?? '';
      final last = _stringFrom(learner['last_name'])?.trim() ?? '';
      final combined = '$first $last'.trim();
      if (combined.isNotEmpty) {
        return combined;
      }
      final email = _stringFrom(learner['email'])?.trim();
      if (email != null && email.isNotEmpty) {
        return email;
      }
    }

    final profile = raw['learner_profile'];
    if (profile is Map<String, dynamic>) {
      final first = _stringFrom(profile['first_name'])?.trim() ?? '';
      final last = _stringFrom(profile['last_name'])?.trim() ?? '';
      final combined = '$first $last'.trim();
      if (combined.isNotEmpty) {
        return combined;
      }
      final email = _stringFrom(profile['email'])?.trim();
      if (email != null && email.isNotEmpty) {
        return email;
      }
    }

    return 'Learner';
  }

  static String? _extractLearnerEmail(Map<String, dynamic> raw) {
    final direct = _firstNonEmpty([raw['learner_email'], raw['email']]);
    if (direct != null) {
      return direct;
    }

    final learner = raw['learner'];
    if (learner is Map<String, dynamic>) {
      final email = _stringFrom(learner['email'])?.trim();
      if (email != null && email.isNotEmpty) {
        return email;
      }
    }

    final profile = raw['learner_profile'];
    if (profile is Map<String, dynamic>) {
      final email = _stringFrom(profile['email'])?.trim();
      if (email != null && email.isNotEmpty) {
        return email;
      }
    }

    return null;
  }

  static String? _extractAvatarUrl(Map<String, dynamic> raw) {
    String? pick(Map<String, dynamic>? source) {
      if (source == null) return null;
      final primary = (source['profile_image_url'] ?? source['avatar_url'])
          ?.toString()
          .trim();
      if (primary != null && primary.isNotEmpty) return primary;
      return null;
    }

    final direct = _stringFrom(raw['avatar_url']);
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();
    if (raw['learner'] is Map<String, dynamic>) {
      final fromLearner =
          pick(Map<String, dynamic>.from(raw['learner'] as Map));
      if (fromLearner != null) return fromLearner;
    }
    if (raw['learner_profile'] is Map<String, dynamic>) {
      final profile = Map<String, dynamic>.from(raw['learner_profile'] as Map);
      final fromProfile = pick(profile);
      if (fromProfile != null) return fromProfile;
      if (profile['profile'] is Map) {
        final nested = Map<String, dynamic>.from(profile['profile'] as Map);
        final nestedPick = pick(nested);
        if (nestedPick != null) return nestedPick;
      }
    }
    return null;
  }

  static String _deriveLocation(Map<String, dynamic> raw) {
    final direct = _firstNonEmpty([
          raw['pickup_location'],
          raw['location'],
          raw['meeting_location'],
          raw['address'],
        ]) ??
        '';
    if (direct.trim().isNotEmpty) return direct.trim();

    List<dynamic>? preferredFrom(Map<String, dynamic>? src) {
      if (src == null) return null;
      final value = src['preferred_locations'];
      return value is List ? value : null;
    }

    List<dynamic>? preferred;
    if (raw['learner'] is Map<String, dynamic>) {
      final learner = Map<String, dynamic>.from(raw['learner'] as Map);
      preferred = preferredFrom(learner) ??
          preferredFrom(learner['profile'] is Map
              ? Map<String, dynamic>.from(learner['profile'] as Map)
              : null);
    }
    if (preferred == null && raw['learner_profile'] is Map<String, dynamic>) {
      final profile = Map<String, dynamic>.from(raw['learner_profile'] as Map);
      preferred = preferredFrom(profile) ??
          preferredFrom(profile['profile'] is Map
              ? Map<String, dynamic>.from(profile['profile'] as Map)
              : null);
    }

    if (preferred != null) {
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

    final city = () {
      if (raw['learner'] is Map<String, dynamic>) {
        final learner = Map<String, dynamic>.from(raw['learner'] as Map);
        final city = (learner['city'] ?? '').toString().trim();
        if (city.isNotEmpty) return city;
        if (learner['profile'] is Map) {
          final nested = Map<String, dynamic>.from(learner['profile'] as Map);
          final nestedCity = (nested['city'] ?? '').toString().trim();
          if (nestedCity.isNotEmpty) return nestedCity;
        }
      }
      if (raw['learner_profile'] is Map<String, dynamic>) {
        final profile =
            Map<String, dynamic>.from(raw['learner_profile'] as Map);
        final profileCity = (profile['city'] ?? '').toString().trim();
        if (profileCity.isNotEmpty) return profileCity;
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

  static String _resolveTimeLabel(Map<String, dynamic> raw) {
    final direct = _firstNonEmpty([raw['time'], raw['time_label']]);
    if (direct != null) {
      return direct;
    }

    DateTime? baseDate;
    final scheduledRaw = raw['scheduled_at']?.toString();
    if (scheduledRaw != null && scheduledRaw.isNotEmpty) {
      baseDate = DateTime.tryParse(scheduledRaw)?.toLocal();
    }

    DateTime? merge(TimeOfDay? time) {
      if (baseDate == null || time == null) return null;
      return DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        time.hour,
        time.minute,
      );
    }

    TimeOfDay? startTime = _parseTime(raw['start_time']);
    TimeOfDay? endTime = _parseTime(raw['end_time']);

    DateTime? start = merge(startTime);
    DateTime? end = merge(endTime);

    if (start == null && baseDate != null) {
      start = baseDate;
    }
    if (start != null && end == null) {
      end = start.add(const Duration(hours: 1));
    }

    if (start != null && end != null) {
      final timeRange =
          '${DateFormat.jm().format(start)} – ${DateFormat.jm().format(end)}';
      return '${DateFormat.yMMMd().format(start)} $timeRange';
    }
    if (start != null) {
      return DateFormat.yMMMd().add_jm().format(start);
    }

    final dateCandidates = [
      raw['scheduled_at'],
      raw['preferred_datetime'],
      raw['preferred_at'],
      raw['requested_datetime'],
      raw['requested_at'],
      raw['requested_start'],
      raw['requested_time'],
      raw['preferred_time'],
      raw['start_time'],
      raw['created_at'],
    ];

    for (final candidate in dateCandidates) {
      final formatted = _formatDateTime(candidate);
      if (formatted != null) {
        return formatted;
      }
    }

    final startLabel = _stringFrom(raw['start_time'])?.trim();
    final endLabel = _stringFrom(raw['end_time'])?.trim();
    if (startLabel != null && startLabel.isNotEmpty) {
      if (endLabel != null && endLabel.isNotEmpty) {
        return '$startLabel - $endLabel';
      }
      return startLabel;
    }

    final dateOnly = _firstNonEmpty(
        [raw['scheduled_date'], raw['preferred_date'], raw['requested_date']]);
    if (dateOnly != null) {
      return dateOnly;
    }

    return 'Schedule pending';
  }

  static String? _formatDateTime(dynamic value) {
    DateTime? dt;
    if (value is DateTime) {
      dt = value;
    } else if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      dt = DateTime.tryParse(trimmed);
    }
    if (dt == null) {
      return null;
    }
    return DateFormat.yMMMd().add_jm().format(dt.toLocal());
  }

  static String? _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      final asString = _stringFrom(value)?.trim();
      if (asString != null && asString.isNotEmpty) {
        return asString;
      }
    }
    return null;
  }

  static String? _stringFrom(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    if (value is num) {
      return value.toString();
    }
    return null;
  }

  static TimeOfDay? _parseTime(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return 'Select';
    final base = DateTime(2026, 1, 1, time.hour, time.minute);
    return DateFormat.jm().format(base);
  }

  String _to24h(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
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

  Future<void> _saveInlineEdit() async {
    if (_saving) return;
    final lessonId = _rawLesson['id']?.toString();
    final date = _selectedDate;
    final start = _startTime;
    if (lessonId == null || lessonId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lesson id is missing.')),
      );
      return;
    }
    if (date == null || start == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a date and start time.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        start.hour,
        start.minute,
      );
      final updated = await SupabaseService.updateLessonDetails(
        lessonId: lessonId,
        scheduledAt: scheduledAt,
        lessonDate: date,
        startTime: _to24h(start),
        endTime: _endTime != null ? _to24h(_endTime!) : null,
        focus: _focusController.text.trim().isEmpty
            ? null
            : _focusController.text.trim(),
        pickupLocation: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        notes: _notesController.text.trim(),
        cost: double.tryParse(_costController.text.trim()),
      );

      if (!mounted) return;
      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save lesson changes.')),
        );
        return;
      }

      setState(() {
        _rawLesson = {..._rawLesson, ...updated};
        _lessonData = _normalizeLessonData(_rawLesson);
        _editing = false;
        _syncEditControllers();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lesson updated.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving lesson: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _lessonData;
    final avatarUrl = (data['avatar_url'] as String?) ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson details'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ocean,
        elevation: 0,
        actions: [
          if (_editing)
            TextButton(
              onPressed: _saving ? null : _saveInlineEdit,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            )
          else
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HeaderCard(data: data, avatarUrl: avatarUrl),
          const SizedBox(height: 20),
          if (_editing)
            _InlineLessonEditForm(
              selectedDate: _selectedDate,
              startTime: _startTime,
              endTime: _endTime,
              focusController: _focusController,
              locationController: _locationController,
              costController: _costController,
              notesController: _notesController,
              onPickDate: _pickDate,
              onPickStartTime: _pickStartTime,
              onPickEndTime: _pickEndTime,
              formatTime: _formatTimeOfDay,
              onCancel: () {
                setState(() {
                  _editing = false;
                  _syncEditControllers();
                });
              },
            )
          else ...[
            _InfoSection(
              title: 'Session info',
              data: data,
              rows: const [
                _InfoRow(label: 'Focus area', valueKey: 'focus'),
                _InfoRow(label: 'Meeting location', valueKey: 'location'),
              ],
            ),
            const SizedBox(height: 20),
            _InfoSection(
              title: 'Notes for the lesson',
              data: data,
              contentKey: 'notes',
              emptyText: 'No notes added.',
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String avatarUrl;

  const _HeaderCard({required this.data, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.ocean.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                backgroundImage:
                    avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        (data['learner'] as String)[0],
                        style: const TextStyle(
                          color: AppColors.ocean,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
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
                      data['learner'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      data['time'] as String,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  data['status'] as String,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<_InfoRow>? rows;
  final String? contentKey;
  final String? emptyText;
  final Map<String, dynamic> data;

  const _InfoSection({
    required this.title,
    this.rows,
    this.contentKey,
    this.emptyText,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ocean,
            ),
          ),
          const SizedBox(height: 12),
          if (rows != null) ...rows!.map((row) => row.build(data)),
          if (contentKey != null)
            Text(
              ((data[contentKey] as String?) ?? '').trim().isEmpty
                  ? (emptyText ?? '')
                  : (data[contentKey] as String),
              style: const TextStyle(height: 1.5),
            ),
        ],
      ),
    );
  }
}

class _InlineLessonEditForm extends StatelessWidget {
  const _InlineLessonEditForm({
    required this.selectedDate,
    required this.startTime,
    required this.endTime,
    required this.focusController,
    required this.locationController,
    required this.costController,
    required this.notesController,
    required this.onPickDate,
    required this.onPickStartTime,
    required this.onPickEndTime,
    required this.formatTime,
    required this.onCancel,
  });

  final DateTime? selectedDate;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final TextEditingController focusController;
  final TextEditingController locationController;
  final TextEditingController costController;
  final TextEditingController notesController;
  final VoidCallback onPickDate;
  final VoidCallback onPickStartTime;
  final VoidCallback onPickEndTime;
  final String Function(TimeOfDay? time) formatTime;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final dateLabel = selectedDate == null
        ? 'Select date'
        : DateFormat.yMMMMd().format(selectedDate!);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edit lesson',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ocean,
            ),
          ),
          const SizedBox(height: 16),
          _EditLabel('Date'),
          OutlinedButton(
            onPressed: onPickDate,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              alignment: Alignment.center,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              dateLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TimePickerButton(
                  label: 'Start time',
                  value: formatTime(startTime),
                  onPressed: onPickStartTime,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimePickerButton(
                  label: 'End time',
                  value: formatTime(endTime),
                  onPressed: onPickEndTime,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _EditField(label: 'Session focus', controller: focusController),
          _EditField(label: 'Pickup location', controller: locationController),
          _EditField(
            label: 'Cost',
            controller: costController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          _EditField(
            label: 'Notes for the lesson',
            controller: notesController,
            minLines: 4,
            maxLines: 5,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onCancel,
              child: const Text('Cancel editing'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditLabel extends StatelessWidget {
  const _EditLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.ocean,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TimePickerButton extends StatelessWidget {
  const _TimePickerButton({
    required this.label,
    required this.value,
    required this.onPressed,
  });

  final String label;
  final String value;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EditLabel(label),
        OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        minLines: minLines,
        maxLines: maxLines,
        textInputAction:
            maxLines > 1 ? TextInputAction.newline : TextInputAction.next,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String valueKey;

  const _InfoRow({required this.label, required this.valueKey});

  Widget build(Map<String, dynamic> data) {
    final value = data[valueKey] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
