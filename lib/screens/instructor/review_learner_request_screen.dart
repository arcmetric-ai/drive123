import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../utils/lesson_request_utils.dart';
import '../../widgets/learner_account_tag.dart';
import '../../widgets/verified_profile_badge.dart';

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
    final request = _request ?? {};
    final nestedLearner = request['learner'] is Map
        ? Map<String, dynamic>.from(request['learner'] as Map)
        : <String, dynamic>{};
    final learnerId =
        request['learner_id'] as String? ?? nestedLearner['id'] as String?;
    if (learnerId == null) return;
    GoRouter.of(context).push(
      AppRoutes.instructorLearnerDetail,
      extra: {
        ...nestedLearner,
        ...request,
        'profile_id': learnerId,
        'id': learnerId,
        'name': _displayName(request),
        'status': (request['status'] as String?) ?? 'pending',
      },
    );
  }

  void _closeWithResult() {
    Navigator.of(context).pop(_request);
  }

  String _displayName(Map<String, dynamic> request) {
    final guardianLearnerName = formatLessonRequestLearnerName(request);
    final learnerProfile = request['learner_profile'];
    if (learnerProfile is Map &&
        _stringValue(learnerProfile['account_type'])?.toLowerCase() ==
            'guardian' &&
        guardianLearnerName != 'Learner') {
      return guardianLearnerName;
    }

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

  String _accountHolderName(Map<String, dynamic> request) {
    final learner = request['learner'] is Map
        ? Map<String, dynamic>.from(request['learner'] as Map)
        : <String, dynamic>{};
    final parts = [
      _stringValue(learner['first_name']),
      _stringValue(learner['last_name']),
    ].whereType<String>().join(' ').trim();
    if (parts.isNotEmpty) return parts;
    return _stringValue(learner['email']) ??
        _stringValue(request['requested_email']) ??
        'Guardian';
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

  bool _isVerifiedLearner(Map<String, dynamic>? request) {
    if (request == null) return false;

    bool? readBool(dynamic value) {
      if (value is bool) return value;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
          return true;
        }
        if (normalized == 'false' || normalized == '0' || normalized == 'no') {
          return false;
        }
      }
      return null;
    }

    final learner = request['learner'];
    final learnerProfile = request['learner_profile'];
    return readBool(request['is_verified']) ??
        (learner is Map ? readBool(learner['is_verified']) : null) ??
        (learnerProfile is Map
            ? readBool(learnerProfile['is_verified'] ??
                (learnerProfile['profile'] is Map
                    ? (learnerProfile['profile'] as Map)['is_verified']
                    : null))
            : null) ??
        false;
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
    final learnerProfile = request?['learner_profile'];
    if (learnerProfile is Map) {
      final wardAge = _parseAge(learnerProfile['ward_age']);
      if (wardAge != null) return wardAge;
    }

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

  Widget _profileSection({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 22, color: AppColors.primary),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
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
    final accountType =
        _stringValue(learnerProfile?['account_type'])?.toLowerCase();
    final isGuardianAccount = accountType == 'guardian';
    final isVerifiedLearner = _isVerifiedLearner(request);
    final accountHolderName = _accountHolderName(request ?? const {});
    final wardFirst = _stringValue(learnerProfile?['ward_first_name']);
    final wardLast = _stringValue(learnerProfile?['ward_last_name']);
    final wardName = [
      if (wardFirst != null) wardFirst,
      if (wardLast != null) wardLast,
    ].join(' ').trim();
    final displayName = isGuardianAccount && wardName.isNotEmpty
        ? wardName
        : _displayName(request ?? const {});
    final wardGender = _stringValue(learnerProfile?['ward_gender']);
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
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: AppColors.border),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A111827),
                                  blurRadius: 16,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 34,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            displayName,
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.foreground,
                                            ),
                                          ),
                                          if (isVerifiedLearner)
                                            const VerifiedProfileBadge(
                                              size: 22,
                                              showCutout: true,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 5,
                                            ),
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
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          if (isGuardianAccount)
                                            const LearnerAccountTag.guardian(),
                                        ],
                                      ),
                                      if (isGuardianAccount) ...[
                                        const SizedBox(height: 10),
                                        Text(
                                          'Managed by $accountHolderName',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.mutedForeground,
                                          ),
                                        ),
                                      ],
                                      if (createdAt != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Requested on ${DateFormat('MMM d, yyyy - h:mm a').format(createdAt)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.mutedForeground,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          _profileSection(
                            title: 'Lesson request',
                            icon: Icons.route_outlined,
                            children: [
                              _detailRow('Focus', focus ?? 'Not provided'),
                              _detailRow(
                                'Vehicle',
                                requestedVehicle ?? 'No preference provided',
                              ),
                              _detailRow(
                                'Message',
                                message?.isNotEmpty == true
                                    ? message!
                                    : 'No message provided.',
                              ),
                            ],
                          ),
                          _profileSection(
                            title: isGuardianAccount
                                ? 'Learner and guardian'
                                : 'Learner profile',
                            icon: isGuardianAccount
                                ? Icons.supervisor_account_outlined
                                : Icons.person_outline,
                            children: [
                              if (isGuardianAccount)
                                _detailRow('Guardian', accountHolderName),
                              _detailRow(
                                'Learner',
                                displayName,
                              ),
                              _detailRow(
                                'Age',
                                age != null ? '$age years' : 'Not provided',
                              ),
                              _detailRow(
                                'Gender',
                                isGuardianAccount
                                    ? wardGender ?? 'Not provided'
                                    : gender ?? 'Not provided',
                              ),
                              _detailRow('City', city ?? 'Not provided'),
                            ],
                          ),
                          if (availabilitySummary != null)
                            _profileSection(
                              title: 'Weekly availability',
                              icon: Icons.access_time,
                              children: [
                                Text(
                                  availabilitySummary,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.45,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.foreground,
                                  ),
                                ),
                              ],
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
                                      vertical: 18,
                                    ),
                                    minimumSize: const Size.fromHeight(58),
                                    textStyle: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    size: 24,
                                  ),
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
                                      width: 2,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    minimumSize: const Size.fromHeight(58),
                                    textStyle: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.cancel_outlined,
                                    size: 24,
                                  ),
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
