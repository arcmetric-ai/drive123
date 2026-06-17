import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
    return SupabaseService.getInstructorProfileDetail(userId);
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
      if (!type.isRequired) return false;
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
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _credentialsFuture,
          builder: (context, snapshot) {
            final profile = snapshot.data ?? const <String, dynamic>{};
            final identityVerified = ((profile['profile']
                        as Map?)?['identity_license_path'] as String?)
                    ?.trim()
                    .isNotEmpty ==
                true;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(
                      foregroundColor: AppColors.foreground,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.border),
                    ),
                    tooltip: 'Back',
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Credentials Portal',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.12,
                      color: AppColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upload and manage the documents Drive Tutor needs to review your instructor account.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 22),
                  InstructorDocumentStatusTile(
                    title: "Driver's License",
                    statusLabel: identityVerified ? 'VERIFIED' : 'REQUIRED',
                    statusColor: identityVerified
                        ? AppColors.success
                        : AppColors.primary,
                    icon: Icons.circle,
                    isComplete: identityVerified,
                    showTrailingArrow: false,
                    onTap: null,
                  ),
                  const SizedBox(height: 18),
                  ...InstructorDocumentType.values.map((type) {
                    final path = profile[type.columnName] as String?;
                    final hasUpload = path != null && path.trim().isNotEmpty;
                    final expiryStatus = _expiryStatusFor(profile, type);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: InstructorDocumentStatusTile(
                        title: type.title,
                        statusLabel: hasUpload
                            ? (expiryStatus ?? 'UPLOADED')
                            : (type.isRequired ? 'REQUIRED' : 'OPTIONAL'),
                        statusColor: hasUpload
                            ? AppColors.primary
                            : (type.isRequired
                                ? AppColors.primary
                                : AppColors.mutedForeground),
                        icon: _iconForType(type),
                        onTap: () => _openUpload(type),
                      ),
                    );
                  }),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_rounded,
                              color: AppColors.mutedForeground,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Review process',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.foreground,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Our team reviews documents within 24 hours. Keep your physical documents ready for quick photo upload.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.45,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  AppPrimaryButton(
                    label: 'Upload Documents',
                    isLoading: _isSubmitting,
                    onPressed:
                        snapshot.connectionState == ConnectionState.waiting
                            ? null
                            : () => _submitForReview(profile),
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
