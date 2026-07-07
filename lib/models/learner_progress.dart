import 'package:flutter/material.dart';

enum LearnerSkillStatus {
  notStarted,
  practicing,
  confident,
  testReady;

  String get storageValue {
    switch (this) {
      case LearnerSkillStatus.notStarted:
        return 'not_started';
      case LearnerSkillStatus.practicing:
        return 'practicing';
      case LearnerSkillStatus.confident:
        return 'confident';
      case LearnerSkillStatus.testReady:
        return 'test_ready';
    }
  }

  String get label {
    switch (this) {
      case LearnerSkillStatus.notStarted:
        return 'Not started';
      case LearnerSkillStatus.practicing:
        return 'Practicing';
      case LearnerSkillStatus.confident:
        return 'Confident';
      case LearnerSkillStatus.testReady:
        return 'Test ready';
    }
  }

  double get score {
    switch (this) {
      case LearnerSkillStatus.notStarted:
        return 0;
      case LearnerSkillStatus.practicing:
        return 1 / 3;
      case LearnerSkillStatus.confident:
        return 2 / 3;
      case LearnerSkillStatus.testReady:
        return 1;
    }
  }

  bool get isTestReady => this == LearnerSkillStatus.testReady;

  static LearnerSkillStatus fromRow(Map<String, dynamic> row) {
    final rawStatus = row['status']?.toString().trim().toLowerCase();
    switch (rawStatus) {
      case 'practicing':
        return LearnerSkillStatus.practicing;
      case 'confident':
        return LearnerSkillStatus.confident;
      case 'test_ready':
      case 'completed':
      case 'complete':
        return LearnerSkillStatus.testReady;
      case 'not_started':
      case 'in_progress':
      case 'not started':
        return LearnerSkillStatus.notStarted;
    }

    return row['is_completed'] == true
        ? LearnerSkillStatus.testReady
        : LearnerSkillStatus.notStarted;
  }
}

class LearnerProgressSkill {
  const LearnerProgressSkill({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.status = LearnerSkillStatus.notStarted,
    this.completedAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final LearnerSkillStatus status;
  final DateTime? completedAt;
  final DateTime? updatedAt;

  LearnerProgressSkill copyWith({
    LearnerSkillStatus? status,
    DateTime? completedAt,
    DateTime? updatedAt,
  }) {
    return LearnerProgressSkill(
      id: id,
      name: name,
      description: description,
      icon: icon,
      status: status ?? this.status,
      completedAt: completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

DateTime? learnerProgressDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

List<LearnerProgressSkill> defaultLearnerProgressSkills() {
  return const [
    LearnerProgressSkill(
      id: 'three_point_turn',
      name: '3 point turn',
      description: 'Controlled turnabout in a confined space',
      icon: Icons.turn_sharp_left_rounded,
    ),
    LearnerProgressSkill(
      id: 'uphill_park',
      name: 'Uphill park',
      description: 'Parking uphill with correct wheel position',
      icon: Icons.local_parking_rounded,
    ),
    LearnerProgressSkill(
      id: 'downhill_park',
      name: 'Downhill park',
      description: 'Parking downhill with correct wheel position',
      icon: Icons.local_parking_rounded,
    ),
    LearnerProgressSkill(
      id: 'reverse_park',
      name: 'Reverse park',
      description: 'Reversing safely into a parking space',
      icon: Icons.drive_eta_rounded,
    ),
    LearnerProgressSkill(
      id: 'parallel_parking',
      name: 'Parallel Parking',
      description: 'Parallel parking with proper observation',
      icon: Icons.local_parking_rounded,
    ),
    LearnerProgressSkill(
      id: 'u_turn_left_turn',
      name: 'U- Turn & Left Turn',
      description: 'Safe U-turns and left turns at intersections',
      icon: Icons.u_turn_left_rounded,
    ),
    LearnerProgressSkill(
      id: 'lane_change',
      name: 'Lane change',
      description: 'Mirror, signal, blind spot, and smooth lane changes',
      icon: Icons.alt_route_rounded,
    ),
    LearnerProgressSkill(
      id: 'emergency_full_stop',
      name: 'Emergency Full Stop',
      description: 'Controlled emergency stop with safe recovery',
      icon: Icons.emergency_rounded,
    ),
  ];
}

List<LearnerProgressSkill> learnerProgressSkillsFromRows(
  List<Map<String, dynamic>> rows,
) {
  final progressById = <String, Map<String, dynamic>>{};
  for (final row in rows) {
    final skillId = row['skill_id']?.toString();
    if (skillId != null && skillId.isNotEmpty) {
      progressById[skillId] = row;
    }
  }

  return defaultLearnerProgressSkills().map((skill) {
    final row = progressById[skill.id];
    if (row == null) return skill;
    final status = LearnerSkillStatus.fromRow(row);
    return skill.copyWith(
      status: status,
      completedAt: learnerProgressDate(row['completed_at']),
      updatedAt: learnerProgressDate(row['updated_at']),
    );
  }).toList();
}
