import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../constants/ontario_locations.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../models/instructor_document_type.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/instructor_document_status_tile.dart';

class InstructorCredentialsPortalScreen extends StatefulWidget {
  const InstructorCredentialsPortalScreen({super.key});

  @override
  State<InstructorCredentialsPortalScreen> createState() =>
      _InstructorCredentialsPortalScreenState();
}

class _InstructorCredentialsPortalScreenState
    extends State<InstructorCredentialsPortalScreen> {
  late Future<Map<String, dynamic>?> _credentialsFuture;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _credentialsFuture = _loadCredentials();
  }

  Future<Map<String, dynamic>?> _loadCredentials() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return null;
    final results = await Future.wait<dynamic>([
      SupabaseService.getInstructorProfileDetail(userId),
      SupabaseService.getPendingDocumentRequests(userId),
    ]);
    final profile = results[0] as Map<String, dynamic>?;
    if (profile == null) return null;
    return {
      ...profile,
      '_document_requests': List<Map<String, dynamic>>.from(results[1] as List),
    };
  }

  Future<void> _refresh() async {
    setState(() {
      _credentialsFuture = _loadCredentials();
    });
  }

  IconData _iconForType(InstructorDocumentType type) {
    switch (type) {
      case InstructorDocumentType.instructorLicense:
        return Icons.badge_outlined;
      case InstructorDocumentType.insuranceDocument:
        return Icons.verified_user_outlined;
      case InstructorDocumentType.backgroundCheck:
        return Icons.fact_check_outlined;
      case InstructorDocumentType.municipalLicense:
        return Icons.location_city_outlined;
    }
  }

  String? _expiryStatusFor(
    Map<String, dynamic> profile,
    InstructorDocumentType type,
  ) {
    final columnName = type.expiryColumnName;
    if (columnName == null) return null;
    final raw = profile[columnName]?.toString();
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return null;
    return 'EXPIRES ${DateFormat('MMM d, yyyy').format(parsed).toUpperCase()}';
  }

  Future<void> _openUpload(InstructorDocumentType type) async {
    await context.push(
      AppRoutes.instructorDocumentUpload,
      extra: {'documentType': type.name},
    );
    if (!mounted) return;
    await _refresh();
  }

  List<String> _serviceLocations(Map<String, dynamic> profile) {
    final locations = <String>{};

    void add(dynamic value) {
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isNotEmpty) {
          locations.add(trimmed);
        }
      }
    }

    void collect(dynamic value) {
      if (value is List) {
        for (final item in value) {
          collect(item);
        }
        return;
      }
      if (value is Map) {
        add(value['city']);
        add(value['service_area_city']);
        add(value['serviceAreaCity']);
        add(value['areaName']);
        add(value['area']);
        add(value['label']);
        add(value['name']);
      }
    }

    collect(profile['preferred_locations']);
    collect(profile['areas_of_operation']);
    add(profile['service_area_city']);
    add(profile['serviceAreaCity']);
    add(profile['service_area']);
    add(profile['serviceArea']);
    final nestedProfile = profile['profile'];
    if (nestedProfile is Map) {
      add(nestedProfile['city']);
    }
    return locations.toList(growable: false);
  }

  bool _isRequiredDocument(
    Map<String, dynamic> profile,
    InstructorDocumentType type,
  ) {
    if (type != InstructorDocumentType.municipalLicense) {
      return type.isRequired;
    }
    return OntarioLocations.municipalLicenseRequiredForLocations(
      _serviceLocations(profile),
    );
  }

  Future<void> _submitForReview(Map<String, dynamic> profile) async {
    if (_isSubmitting) return;
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in again to continue.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final missingRequired = InstructorDocumentType.values.where((type) {
      if (!_isRequiredDocument(profile, type)) return false;
      final path = profile[type.columnName] as String?;
      return path == null || path.trim().isEmpty;
    }).toList();

    if (missingRequired.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Upload all required documents before submitting for review.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await SupabaseService.submitInstructorCredentialsForReview(
          userId: userId);
      if (!mounted) return;
      context
          .go(AppRoutes.identityPendingReview, extra: {'role': 'instructor'});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to submit credentials: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Credentials Portal'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.foreground,
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _credentialsFuture,
          builder: (context, snapshot) {
            final profile = snapshot.data ?? const <String, dynamic>{};
            final documentRequests = List<Map<String, dynamic>>.from(
              (profile['_document_requests'] as List?) ?? const [],
            )
                .where(
                  (request) =>
                      request['review_type'] == 'instructor_credentials',
                )
                .toList();
            final requestedTypes = documentRequests
                .map((request) => request['document_type']?.toString())
                .whereType<String>()
                .toSet();
            final identityVerified = ((profile['profile']
                        as Map?)?['identity_license_path'] as String?)
                    ?.trim()
                    .isNotEmpty ==
                true;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Keep each credential current, then submit everything for review.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (documentRequests.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Drive Tutor requested an update',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            documentRequests
                                .map((request) =>
                                    request['admin_message']?.toString().trim())
                                .whereType<String>()
                                .where((message) => message.isNotEmpty)
                                .join('\n'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  InstructorDocumentStatusTile(
                    title: 'Ontario G Licence',
                    statusLabel: identityVerified ? 'VERIFIED' : 'REQUIRED',
                    statusColor: identityVerified
                        ? AppColors.success
                        : AppColors.primary,
                    icon: Icons.circle,
                    isComplete: identityVerified,
                    showTrailingArrow: false,
                    onTap: null,
                    compact: true,
                  ),
                  const SizedBox(height: 8),
                  ...InstructorDocumentType.values.map((type) {
                    final isRequired = _isRequiredDocument(profile, type);
                    final path = profile[type.columnName] as String?;
                    final hasUpload = path != null && path.trim().isNotEmpty;
                    final expiryStatus = _expiryStatusFor(profile, type);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InstructorDocumentStatusTile(
                        title: type.title,
                        statusLabel: hasUpload
                            ? (requestedTypes.contains(type.storageKey)
                                ? 'UPDATE REQUESTED'
                                : (expiryStatus ?? 'UPLOADED'))
                            : (isRequired ? 'REQUIRED' : 'OPTIONAL'),
                        statusColor: requestedTypes.contains(type.storageKey)
                            ? AppColors.error
                            : hasUpload
                                ? AppColors.primary
                                : (isRequired
                                    ? AppColors.primary
                                    : AppColors.mutedForeground),
                        icon: _iconForType(type),
                        onTap: () => _openUpload(type),
                        compact: true,
                      ),
                    );
                  }),
                  const Spacer(),
                  AppPrimaryButton(
                    label: 'Submit Documents',
                    isLoading: _isSubmitting,
                    onPressed:
                        snapshot.connectionState == ConnectionState.waiting
                            ? null
                            : () => _submitForReview(profile),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'After submission, our team will respond within 24 hours.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
