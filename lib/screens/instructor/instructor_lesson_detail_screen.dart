import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../models/lesson_model.dart';

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
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final updated = await GoRouter.of(context).push(
                AppRoutes.instructorLessonEdit,
                extra: {..._rawLesson, ..._lessonData},
              );
              if (updated is Map<String, dynamic>) {
                setState(() {
                  _rawLesson = updated;
                  _lessonData = _normalizeLessonData(updated);
                });
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _HeaderCard(data: data, avatarUrl: avatarUrl),
          const SizedBox(height: 20),
          _InfoSection(
            title: 'Session info',
            data: data,
            rows: const [
              _InfoRow(label: 'Focus area', valueKey: 'focus'),
              _InfoRow(label: 'Meeting location', valueKey: 'location'),
            ],
          ),
          if (((data['notes'] as String?) ?? '').isNotEmpty) ...[
            const SizedBox(height: 20),
            _InfoSection(
              title: 'Notes for the lesson',
              data: data,
              contentKey: 'notes',
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
  final Map<String, dynamic> data;

  const _InfoSection({
    required this.title,
    this.rows,
    this.contentKey,
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
              data[contentKey] as String? ?? '',
              style: const TextStyle(height: 1.5),
            ),
        ],
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
