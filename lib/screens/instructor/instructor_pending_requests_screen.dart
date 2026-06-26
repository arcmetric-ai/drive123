import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../utils/lesson_request_utils.dart';
import '../../widgets/learner_account_tag.dart';
import '../../widgets/verified_profile_badge.dart';

class InstructorPendingRequestsScreen extends StatefulWidget {
  const InstructorPendingRequestsScreen({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 32),
  });

  final EdgeInsetsGeometry padding;

  @override
  State<InstructorPendingRequestsScreen> createState() =>
      _InstructorPendingRequestsScreenState();
}

class _InstructorPendingRequestsScreenState
    extends State<InstructorPendingRequestsScreen> {
  bool _loading = true;
  bool _error = false;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final instructorId = SupabaseService.currentUser?.id;
    if (instructorId == null) {
      setState(() {
        _loading = false;
        _error = true;
        _requests = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final requests =
          await SupabaseService.getLessonRequestsForInstructor(instructorId);
      if (!mounted) return;
      setState(() {
        _requests = requests
            .where((request) =>
                ((request['status'] as String?) ?? '').toLowerCase() ==
                'pending')
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
        _requests = [];
      });
    }
  }

  Future<void> _openRequest(Map<String, dynamic> request) async {
    final updated = await context.push<Map<String, dynamic>>(
      AppRoutes.reviewLearnerRequest,
      extra: request,
    );
    if (!mounted) return;
    if (updated != null) {
      await _load();
    }
  }

  String? _avatarUrl(Map<String, dynamic> request) {
    final direct =
        (request['requested_profile_url'] ?? request['requested_avatar_url'])
            ?.toString()
            .trim();
    if (direct != null && direct.isNotEmpty) return direct;

    final learner = request['learner'];
    if (learner is Map) {
      final candidate = (learner['profile_image_url'] ?? learner['avatar_url'])
          ?.toString()
          .trim();
      if (candidate != null && candidate.isNotEmpty) return candidate;
    }
    return null;
  }

  String _subtitle(Map<String, dynamic> request) {
    if (_isGuardianAccount(request)) {
      final guardianName = _accountHolderName(request);
      if (guardianName.isNotEmpty) {
        return 'Managed by $guardianName';
      }
      return 'Guardian account';
    }
    final focus = (request['focus'] as String?)?.trim();
    if (focus != null && focus.isNotEmpty) return focus;
    final city = ((request['requested_city'] ??
                (request['learner'] is Map ? request['learner']['city'] : null))
            as String?)
        ?.trim();
    if (city != null && city.isNotEmpty) return city;
    return 'New learner inquiry';
  }

  bool _isGuardianAccount(Map<String, dynamic> request) {
    final learnerProfile = request['learner_profile'];
    if (learnerProfile is Map) {
      return cleanDisplayString(learnerProfile['account_type']).toLowerCase() ==
          'guardian';
    }
    return false;
  }

  bool _isOfflineRequest(Map<String, dynamic> request) {
    return request['is_external_learner'] == true ||
        request['is_offline'] == true ||
        cleanDisplayString(request['external_learner_id']).isNotEmpty;
  }

  String _accountHolderName(Map<String, dynamic> request) {
    final learner = request['learner'];
    if (learner is Map) {
      final parts = [
        cleanDisplayString(learner['first_name']),
        cleanDisplayString(learner['last_name']),
      ].where((value) => value.isNotEmpty).join(' ');
      if (parts.isNotEmpty) return parts;
      final email = cleanDisplayString(learner['email']);
      if (email.isNotEmpty) return email;
    }

    final requested = [
      cleanDisplayString(request['requested_first_name']),
      cleanDisplayString(request['requested_last_name']),
    ].where((value) => value.isNotEmpty).join(' ');
    if (requested.isNotEmpty) return requested;

    final fallback = cleanDisplayString(request['requested_name']);
    return fallback.isNotEmpty ? fallback : 'Learner';
  }

  String _guardianLearnerName(Map<String, dynamic> request) {
    final learnerProfile = request['learner_profile'];
    if (learnerProfile is Map) {
      final wardName = [
        cleanDisplayString(learnerProfile['ward_first_name']),
        cleanDisplayString(learnerProfile['ward_last_name']),
      ].where((value) => value.isNotEmpty).join(' ');
      if (wardName.isNotEmpty) return wardName;
    }
    return '';
  }

  bool _isVerifiedLearner(Map<String, dynamic> request) {
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

  String _timestampLabel(Map<String, dynamic> request) {
    final raw = request['created_at']?.toString();
    final createdAt = raw != null ? DateTime.tryParse(raw) : null;
    if (createdAt == null) return 'Just now';
    return DateFormat('MMM d • h:mm a').format(createdAt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Requests',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          size: 44,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Unable to load requests',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please try again in a moment.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.mutedForeground),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: widget.padding,
                    children: [
                      const Text(
                        'Pending Requests',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          letterSpacing: -0.7,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _requests.isEmpty
                            ? 'No pending learner requests right now.'
                            : '${_requests.length} learner request${_requests.length == 1 ? '' : 's'} waiting for review.',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_requests.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: AppColors.border),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A111827),
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.mark_email_unread_outlined,
                                color: AppColors.primary,
                                size: 40,
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Nothing to review yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.foreground,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'When new learners request lessons, they will appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.45,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._requests.map(_buildRequestCard),
                    ],
                  ),
                ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final isGuardian = _isGuardianAccount(request);
    final isOffline = _isOfflineRequest(request);
    final name = isGuardian
        ? (_guardianLearnerName(request).isNotEmpty
            ? _guardianLearnerName(request)
            : formatLessonRequestLearnerName(request))
        : formatLessonRequestLearnerName(request);
    final subtitle = _subtitle(request);
    final avatarUrl = _avatarUrl(request);
    final timestamp = _timestampLabel(request);
    final isVerified = _isVerifiedLearner(request);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _openRequest(request),
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(28),
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
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.secondary,
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            color: AppColors.foreground,
                          ),
                        ),
                        if (isVerified)
                          const VerifiedProfileBadge(
                            size: 22,
                            showCutout: true,
                          ),
                        if (isGuardian) const LearnerAccountTag.guardian(),
                        if (isOffline) const LearnerAccountTag.offline(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      timestamp,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.chevron_right_rounded,
                size: 30,
                color: AppColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
