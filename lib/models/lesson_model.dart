import 'package:intl/intl.dart';

import 'instructor_model.dart';

enum LessonStatus {
  scheduled,
  completed,
  cancelled,
  inProgress,
}

class LessonModel {
  LessonModel({
    required this.id,
    required this.learnerId,
    required this.instructor,
    required this.scheduledDate,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.cost,
    required this.status,
    this.focus,
    this.notes,
    this.location,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    final durationHours = (() {
      final rawHours = json['duration_hours'];
      if (rawHours is num) {
        return _normalizeDuration(rawHours.toDouble());
      }
      final mins = json['duration_minutes'];
      if (mins is num) {
        return _normalizeDuration(mins.toDouble() / 60.0);
      }
      final dur = json['duration'];
      if (dur is num) {
        return _normalizeDuration(dur.toDouble());
      }
      return 1.0;
    })();

    double parseCost(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
      return 0.0;
    }

    return LessonModel(
      id: json['id'] as String,
      learnerId:
          (json['learner_id'] ?? json['external_learner_id'] ?? '') as String,
      instructor:
          InstructorModel.fromJson(json['instructor'] as Map<String, dynamic>),
      scheduledDate: DateTime.parse(json['scheduled_at'] as String),
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      duration: durationHours,
      cost: parseCost(json['cost']),
      status: LessonModel.parseStatus(json['status'] as String?),
      focus: json['focus'] as String?,
      notes: json['notes'] as String?,
      location: _parseLocation(json),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
  final String id;
  final String learnerId;
  final InstructorModel instructor;
  final DateTime scheduledDate;
  final String startTime;
  final String endTime;
  final double duration; // in hours
  final double cost;
  final LessonStatus status;
  final String? focus;
  final String? notes;
  final String? location;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'learner_id': learnerId,
      'instructor': instructor.toJson(),
      'scheduled_at': scheduledDate.toIso8601String(),
      'start_time': startTime,
      'end_time': endTime,
      'duration_hours': _normalizeDuration(duration),
      'cost': cost,
      'status': status.name,
      'focus': focus,
      'notes': notes,
      'pickup_location': location,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isUpcoming =>
      effectiveStatus == LessonStatus.scheduled &&
      scheduledDate.isAfter(DateTime.now());

  bool get isCompleted => effectiveStatus == LessonStatus.completed;
  bool get isCancelled => effectiveStatus == LessonStatus.cancelled;
  bool get isInProgress => effectiveStatus == LessonStatus.inProgress;

  LessonStatus get effectiveStatus => deriveStatus(
        scheduledDate: scheduledDate,
        startTime: startTime,
        endTime: endTime,
        durationHours: duration,
        fallbackStatus: status,
      );

  LessonModel copyWith({
    String? id,
    String? learnerId,
    InstructorModel? instructor,
    DateTime? scheduledDate,
    String? startTime,
    String? endTime,
    double? duration,
    double? cost,
    LessonStatus? status,
    String? focus,
    String? notes,
    String? location,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LessonModel(
      id: id ?? this.id,
      learnerId: learnerId ?? this.learnerId,
      instructor: instructor ?? this.instructor,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      duration: duration ?? this.duration,
      cost: cost ?? this.cost,
      status: status ?? this.status,
      focus: focus ?? this.focus,
      notes: notes ?? this.notes,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static double _normalizeDuration(double value) {
    if (value.isNaN || value.isInfinite) return 1.0;
    if (value <= 0) return 1.0;
    return double.parse(value.toStringAsFixed(2));
  }

  static LessonStatus parseStatus(String? raw) {
    final normalized = raw?.toLowerCase().trim() ?? '';
    switch (normalized) {
      case 'completed':
        return LessonStatus.completed;
      case 'cancelled':
        return LessonStatus.cancelled;
      case 'in_progress':
      case 'inprogress':
      case 'active':
        return LessonStatus.inProgress;
      default:
        return LessonStatus.scheduled;
    }
  }

  static LessonStatus deriveStatus({
    required DateTime scheduledDate,
    required String startTime,
    required String endTime,
    required LessonStatus fallbackStatus,
    double? durationHours,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    if (fallbackStatus == LessonStatus.cancelled) return LessonStatus.cancelled;
    if (fallbackStatus == LessonStatus.completed) return LessonStatus.completed;

    final localDate = scheduledDate.toLocal();
    final start = _combineDateAndTime(localDate, startTime);
    final end = _combineDateAndTime(localDate, endTime) ??
        start?.add(Duration(
          minutes: (durationHours != null ? durationHours * 60 : 60).round(),
        ));

    if (end != null && !end.isAfter(clock)) {
      return LessonStatus.completed;
    }

    if (fallbackStatus == LessonStatus.inProgress) {
      return LessonStatus.inProgress;
    }

    if (start != null &&
        start.isBefore(clock) &&
        (end == null || end.isAfter(clock))) {
      return LessonStatus.inProgress;
    }

    return fallbackStatus;
  }

  static DateTime? _combineDateAndTime(DateTime date, String? rawTime) {
    if (rawTime == null || rawTime.trim().isEmpty) return null;
    final formats = <DateFormat>[
      DateFormat('h:mm a'),
      DateFormat('hh:mm a'),
      DateFormat('H:mm'),
      DateFormat('HH:mm:ss'),
      DateFormat('HH:mm'),
    ];

    for (final format in formats) {
      try {
        final parsed = format.parse(rawTime.trim());
        return DateTime(
          date.year,
          date.month,
          date.day,
          parsed.hour,
          parsed.minute,
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  static String? _parseLocation(Map<String, dynamic> json) {
    final rawLocation = json.containsKey('pickup_location')
        ? json['pickup_location']
        : json['location'];
    if (rawLocation is String) {
      final trimmed = rawLocation.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }
}
