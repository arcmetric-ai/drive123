import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../services/supabase_service.dart';

class ReviewLearnerRequestScreen extends StatefulWidget {
  final Map<String, dynamic>? request;

  const ReviewLearnerRequestScreen({super.key, this.request});

  @override
  State<ReviewLearnerRequestScreen> createState() =>
      _ReviewLearnerRequestScreenState();
}

class _ReviewLearnerRequestScreenState
    extends State<ReviewLearnerRequestScreen> {
  Map<String, dynamic>? _request;
  bool _loading = true;
  bool _updating = false;
  String? _pendingDecision;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final initial = widget.request ?? <String, dynamic>{};
    final requestId = initial['id'] as String?;
    if (requestId == null) {
      setState(() {
        _request = initial;
        _loading = false;
      });
      return;
    }

    try {
      final latest = await SupabaseService.getLearnerRequestById(requestId);
      if (!mounted) return;
      setState(() {
        _request = latest ?? Map<String, dynamic>.from(initial);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _request = Map<String, dynamic>.from(initial);
        _loading = false;
      });
    }
  }

  Future<void> _handleDecision(String targetStatus) async {
    final requestId = _request?['id'] as String?;
    if (requestId == null || _updating) return;

    setState(() {
      _updating = true;
      _pendingDecision = targetStatus;
    });
    try {
      final updated = await SupabaseService.respondToLessonRequest(
        requestId: requestId,
        status: targetStatus,
      );
      if (!mounted) return;
      if (updated != null) {
        setState(() => _request = updated);
      } else {
        setState(() {
          _request = {
            ...?_request,
            'status': targetStatus,
          };
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            targetStatus == 'accepted'
                ? 'Request accepted.'
                : 'Request declined.',
          ),
          backgroundColor:
              targetStatus == 'accepted' ? AppColors.success : AppColors.error,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update request: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updating = false;
          _pendingDecision = null;
        });
      }
    }
  }

  void _openProfile() {
    final learner = _request ?? {};
    final learnerId = learner['learner_id'] as String? ??
        (learner['learner'] as Map?)?['id'] as String?;
    if (learnerId == null) return;
    GoRouter.of(context).push(
      AppRoutes.instructorLearnerDetail,
      extra: {
        'profile_id': learnerId,
        'name': _displayName(learner),
        'status': (learner['status'] as String?) ?? 'pending',
      },
    );
  }

  void _closeWithResult() {
    Navigator.of(context).pop(_request);
  }

  String _displayName(Map<String, dynamic> request) {
    final learner = request['learner'] is Map
        ? Map<String, dynamic>.from(request['learner'] as Map)
        : <String, dynamic>{};
    final parts = <String>[];
    final first = (learner['first_name'] as String?)?.trim();
    final last = (learner['last_name'] as String?)?.trim();
    if (first != null && first.isNotEmpty) parts.add(first);
    if (last != null && last.isNotEmpty) parts.add(last);
    if (parts.isNotEmpty) return parts.join(' ');
    final name = (learner['name'] as String?) ??
        (request['requested_name'] as String?) ??
        (request['requested_email'] as String?) ??
        '';
    return name.isNotEmpty ? name : 'Learner';
  }

  String _statusLabel(String status) {
    final normalized = status.toLowerCase();
    switch (normalized) {
      case 'accepted':
      case 'active':
      case 'in_progress':
        return 'Accepted';
      case 'declined':
      case 'rejected':
        return 'Declined';
      case 'removed':
        return 'Removed';
      case 'pending':
        return 'Pending';
      default:
        return normalized.isNotEmpty
            ? normalized[0].toUpperCase() + normalized.substring(1)
            : status;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'active':
      case 'in_progress':
        return AppColors.success;
      case 'declined':
      case 'rejected':
      case 'removed':
        return AppColors.error;
      case 'pending':
      default:
        return AppColors.golden;
    }
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  String? _stringValue(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return null;
      return trimmed;
    }
    return null;
  }

  String? _formatWeeklyAvailability(
      dynamic availabilityRaw, dynamic recurringRaw) {
    final availability = _normalizeWeeklyAvailability(availabilityRaw);
    if (availability.isEmpty) return null;
    final entries = availability.entries.toList()
      ..sort((a, b) => _weekdayOrder(a.key).compareTo(_weekdayOrder(b.key)));
    final lines = <String>[];
    for (final entry in entries) {
      final dayLabel = _capitalize(entry.key);
      final slots = entry.value
          .map((slot) => slot[0].toUpperCase() + slot.substring(1))
          .join(', ');
      lines.add('$dayLabel: $slots');
    }
    final recurring = recurringRaw == true ? 'Yes' : 'No';
    lines.add('Recurring weekly: $recurring');
    return lines.join('\n');
  }

  Map<String, List<String>> _normalizeWeeklyAvailability(dynamic raw) {
    final result = <String, List<String>>{};
    if (raw is Map) {
      raw.forEach((key, value) {
        final day = key.toString().toLowerCase();
        final slots = (value as List?)
                ?.whereType<String>()
                .map((slot) => slot.toLowerCase())
                .where((slot) => slot.isNotEmpty)
                .toSet()
                .toList() ??
            const <String>[];
        if (day.isNotEmpty && slots.isNotEmpty) {
          slots.sort();
          result[day] = slots;
        }
      });
    } else if (raw is Iterable) {
      for (final entry in raw) {
        if (entry is Map) {
          final day = entry['day']?.toString().toLowerCase();
          final slots = (entry['slots'] as List?)
                  ?.whereType<String>()
                  .map((slot) => slot.toLowerCase())
                  .where((slot) => slot.isNotEmpty)
                  .toSet()
                  .toList() ??
              const <String>[];
          if (day != null && day.isNotEmpty && slots.isNotEmpty) {
            slots.sort();
            result[day] = slots;
          }
        }
      }
    }
    return result;
  }

  int _weekdayOrder(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
        return 0;
      case 'tuesday':
        return 1;
      case 'wednesday':
        return 2;
      case 'thursday':
        return 3;
      case 'friday':
        return 4;
      case 'saturday':
        return 5;
      case 'sunday':
        return 6;
      default:
        return 7;
    }
  }

  int? _parseAge(dynamic value) {
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

  int? _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    final hasHadBirthday = (now.month > birthDate.month) ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!hasHadBirthday) {
      age -= 1;
    }
    return age >= 0 ? age : null;
  }

  int? _deriveAge(Map<String, dynamic> learner, Map<String, dynamic>? request) {
    final ageSources = [
      learner['age'],
      request?['age'],
      request?['requested_age'],
    ];
    for (final source in ageSources) {
      final parsed = _parseAge(source);
      if (parsed != null) return parsed;
    }

    final birthSources = [
      learner['date_of_birth'],
      learner['dob'],
      request?['date_of_birth'],
      request?['dob'],
    ];
    for (final source in birthSources) {
      final birthDate = _parseDate(source);
      if (birthDate != null) {
        final computed = _calculateAge(birthDate);
        if (computed != null) return computed;
      }
    }
    return null;
  }

  Widget _infoTile(String title, String value, {IconData? icon}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 2),
              child: Icon(icon, color: AppColors.ocean),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.2,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = _request;
    final status = (request?['status'] as String?) ?? 'pending';
    final learner = request?['learner'] is Map
        ? Map<String, dynamic>.from(request!['learner'] as Map)
        : <String, dynamic>{};
    final learnerProfile = request?['learner_profile'] is Map
        ? Map<String, dynamic>.from(request!['learner_profile'] as Map)
        : null;
    final profileImage = (learner['profile_image_url'] as String?) ??
        (request?['requested_profile_url'] as String?);
    final focus = (request?['focus'] as String?)?.trim();
    final requestedVehicle =
        (request?['requested_vehicle_label'] as String?)?.trim();
    final message = (request?['message'] as String?)?.trim();
    final createdAtRaw = request?['created_at']?.toString();
    final createdAt = createdAtRaw != null
        ? DateTime.tryParse(createdAtRaw)?.toLocal()
        : null;
    final normalizedStatus = status.toLowerCase();
    final isAcceptedStatus =
        {'accepted', 'active', 'in_progress'}.contains(normalizedStatus);
    final isDeclinedStatus = {'declined', 'rejected', 'removed', 'cancelled'}
        .contains(normalizedStatus);
    final gender = _stringValue(learner['gender']) ??
        _stringValue(request?['requested_gender']) ??
        _stringValue(request?['gender']);
    final city = _stringValue(learner['city']) ??
        _stringValue(request?['requested_city']) ??
        _stringValue(request?['city']);
    final age = _deriveAge(learner, request);
    final availabilitySummary = _formatWeeklyAvailability(
      learner['weekly_availability'] ??
          request?['weekly_availability'] ??
          learnerProfile?['weekly_availability'] ??
          request?['availability'] ??
          request?['availability_data'],
      learner['availability_recurring'] ??
          request?['availability_recurring'] ??
          learnerProfile?['availability_recurring'],
    );

    return WillPopScope(
      onWillPop: () async {
        _closeWithResult();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Review Learner Request'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _closeWithResult,
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : request == null
                ? const Center(
                    child: Text('Request could not be found.'),
                  )
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor:
                                    AppColors.ocean.withOpacity(0.12),
                                backgroundImage: profileImage != null
                                    ? NetworkImage(profileImage)
                                    : null,
                                child: profileImage == null
                                    ? const Icon(Icons.person,
                                        color: AppColors.ocean, size: 32)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _displayName(request),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status)
                                            .withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        _statusLabel(status),
                                        style: TextStyle(
                                          color: _statusColor(status),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (createdAt != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Requested on ${DateFormat('MMM d, yyyy - h:mm a').format(createdAt)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          if (focus != null && focus.isNotEmpty)
                            _infoTile('Focus', focus,
                                icon: Icons.center_focus_strong),
                          if (requestedVehicle != null &&
                              requestedVehicle.isNotEmpty)
                            _infoTile(
                              'Preferred vehicle',
                              requestedVehicle,
                              icon: Icons.directions_car_outlined,
                            ),
                          _infoTile(
                            'Message',
                            message?.isNotEmpty == true
                                ? message!
                                : 'No message provided.',
                            icon: Icons.message_outlined,
                          ),
                          if (availabilitySummary != null)
                            _infoTile(
                              'Weekly availability',
                              availabilitySummary,
                              icon: Icons.access_time,
                            ),
                          _infoTile(
                            'Age',
                            age != null ? '$age years' : 'Not provided',
                            icon: Icons.cake_outlined,
                          ),
                          _infoTile(
                            'Gender',
                            gender ?? 'Not provided',
                            icon: Icons.wc_outlined,
                          ),
                          _infoTile(
                            'City',
                            city ?? 'Not provided',
                            icon: Icons.location_city_outlined,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _openProfile,
                              icon: const Icon(Icons.person_search),
                              label: const Text('View Profile'),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _updating || isAcceptedStatus
                                      ? null
                                      : () => _handleDecision('accepted'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: _updating &&
                                          _pendingDecision == 'accepted'
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : const Text('Accept'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _updating ||
                                          isDeclinedStatus ||
                                          isAcceptedStatus
                                      ? null
                                      : () => _handleDecision('declined'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: AppColors.error,
                                    side: const BorderSide(
                                      color: AppColors.error,
                                      width: 1.2,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                  ),
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: _updating &&
                                          _pendingDecision == 'declined'
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    AppColors.error),
                                          ),
                                        )
                                      : const Text('Reject'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }
}
