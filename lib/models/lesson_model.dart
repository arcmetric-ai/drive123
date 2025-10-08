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
    this.notes,
    this.location,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LessonModel.fromJson(Map<String, dynamic> json) {
    return LessonModel(
      id: json['id'] as String,
      learnerId: json['learner_id'] as String,
      instructor:
          InstructorModel.fromJson(json['instructor'] as Map<String, dynamic>),
      scheduledDate: DateTime.parse(json['scheduled_date'] as String),
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      duration: (json['duration'] as num).toDouble(),
      cost: (json['cost'] as num).toDouble(),
      status: LessonStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => LessonStatus.scheduled,
      ),
      notes: json['notes'] as String?,
      location: json['location'] as String?,
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
  final String? notes;
  final String? location;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'learner_id': learnerId,
      'instructor': instructor.toJson(),
      'scheduled_date': scheduledDate.toIso8601String(),
      'start_time': startTime,
      'end_time': endTime,
      'duration': duration,
      'cost': cost,
      'status': status.name,
      'notes': notes,
      'location': location,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isUpcoming =>
      status == LessonStatus.scheduled && scheduledDate.isAfter(DateTime.now());

  bool get isCompleted => status == LessonStatus.completed;
  bool get isCancelled => status == LessonStatus.cancelled;
  bool get isInProgress => status == LessonStatus.inProgress;
}
