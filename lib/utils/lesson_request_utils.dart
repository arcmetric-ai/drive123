String cleanDisplayString(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.toLowerCase() == 'null') return '';
    return trimmed;
  }
  return '';
}

String formatLessonRequestLearnerName(Map<String, dynamic> request) {
  Map<String, dynamic>? learner;
  final learnerValue = request['learner'];
  if (learnerValue is Map<String, dynamic>) {
    learner = learnerValue;
  }

  if (learner != null) {
    final first = cleanDisplayString(learner['first_name']);
    final last = cleanDisplayString(learner['last_name']);
    final parts = <String>[
      if (first.isNotEmpty) first,
      if (last.isNotEmpty) last,
    ];
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
    final learnerEmail = cleanDisplayString(learner['email']);
    if (learnerEmail.isNotEmpty) {
      return learnerEmail;
    }
  }

  final fallbackNameCandidates = [
    [
      cleanDisplayString(request['requested_first_name']),
      cleanDisplayString(request['requested_last_name']),
    ].where((value) => value.isNotEmpty).join(' '),
    request['requested_name'],
    request['name'],
    request['learner_name'],
  ];
  for (final candidate in fallbackNameCandidates) {
    final value = cleanDisplayString(candidate);
    if (value.isNotEmpty) {
      return value;
    }
  }

  final fallbackEmailCandidates = [
    request['requested_email'],
    request['email'],
    request['learner_email'],
    learner?['email'],
  ];
  for (final candidate in fallbackEmailCandidates) {
    final value = cleanDisplayString(candidate);
    if (value.isNotEmpty) {
      return value;
    }
  }

  return 'Learner';
}
