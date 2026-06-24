import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_radii.dart';
import '../../constants/app_shadows.dart';
import '../../constants/app_spacing.dart';
import '../../models/identity_verification_state.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_outline_button.dart';
import '../../widgets/verification_timeline.dart';

class IdentityPendingReviewScreen extends StatelessWidget {
  const IdentityPendingReviewScreen({
    super.key,
    required this.role,
    this.licenseImagePath,
    this.selfieImagePath,
  });

  final String role;
  final String? licenseImagePath;
  final String? selfieImagePath;

  Future<_PendingReviewData> _loadReviewData() async {
    final state = await SupabaseService.getCurrentIdentityVerificationState();
    final userId = SupabaseService.currentUser?.id;
    final requests = userId == null
        ? <Map<String, dynamic>>[]
        : await SupabaseService.getPendingDocumentRequests(userId);
    return _PendingReviewData(state: state, requests: requests);
  }

  Future<void> _redirectAfterApproval(BuildContext context) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      if (context.mounted) context.go(AppRoutes.auth);
      return;
    }

    final route = await SupabaseService.resolvePostAuthRoute(
      userId: userId,
      metadataRole: role,
    );
    if (!context.mounted) return;
    context.go(route);
  }

  Future<void> _handleReturnToSignIn(BuildContext context) async {
    try {
      await SupabaseService.signOut();
    } catch (_) {
      // If sign-out fails, still return the user to auth instead of trapping them.
    }

    if (!context.mounted) return;
    context.go(AppRoutes.auth);
  }

  String _formatTimelineDate(DateTime? value) {
    if (value == null) return '';
    return DateFormat('MMM d, yyyy • h:mm a').format(value.toLocal());
  }

  String _displayName(IdentityVerificationState state) {
    final firstName = state.firstName?.trim();
    if (firstName != null && firstName.isNotEmpty) return firstName;
    final email = SupabaseService.currentUser?.email?.trim();
    if (email != null && email.contains('@')) {
      final candidate = email.split('@').first.trim();
      if (candidate.isNotEmpty) {
        return '${candidate[0].toUpperCase()}${candidate.substring(1)}';
      }
    }
    return 'there';
  }

  String _requestTitle(String? documentType) {
    switch (documentType) {
      case 'identity_license':
        return 'Ontario G1, G2, or G licence';
      case 'identity_selfie':
        return 'Selfie photo';
      case 'guardian_identity_license':
        return 'Guardian government ID';
      case 'guardian_identity_selfie':
        return 'Guardian selfie photo';
      default:
        return 'Requested document';
    }
  }

  IconData _requestIcon(String? documentType) {
    return documentType?.contains('selfie') == true
        ? Icons.face_retouching_natural_rounded
        : Icons.badge_outlined;
  }

  Widget _buildRequestedDocumentsCard({
    required BuildContext context,
    required List<Map<String, dynamic>> requests,
    required String effectiveRole,
  }) {
    if (requests.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.assignment_late_rounded,
                color: AppColors.primary,
                size: 24,
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Requested documents',
                  style: TextStyle(
                    color: AppColors.foreground,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Upload the item requested by the review team. We will restart review after it is submitted.',
            style: TextStyle(
              color: AppColors.mutedForeground,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...requests.map((request) {
            final documentType = request['document_type'] as String?;
            final adminMessage = (request['admin_message'] as String?)?.trim();
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _requestIcon(documentType),
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _requestTitle(documentType),
                          style: const TextStyle(
                            color: AppColors.foreground,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (adminMessage != null &&
                            adminMessage.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            adminMessage,
                            style: const TextStyle(
                              color: AppColors.mutedForeground,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        FilledButton.icon(
                          onPressed: () => context.go(
                            AppRoutes.verificationDocumentResubmission,
                            extra: {
                              'role': effectiveRole,
                              'documentType':
                                  documentType ?? 'identity_license',
                              'requestId': request['id'] as String?,
                              'adminMessage': adminMessage,
                            },
                          ),
                          icon: const Icon(Icons.camera_alt_rounded, size: 18),
                          label: const Text('Upload'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCredentialRequestCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Credential document requested',
            style: TextStyle(
              color: AppColors.foreground,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Open the credentials portal to upload the instructor document requested by admin.',
            style: TextStyle(
              color: AppColors.mutedForeground,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: () => context.go(AppRoutes.instructorCredentialsPortal),
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text('Open credentials portal'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<_PendingReviewData>(
        future: _loadReviewData(),
        builder: (context, snapshot) {
          final data = snapshot.data;
          final state = data?.state;
          final requests = data?.requests ?? const <Map<String, dynamic>>[];
          final displayName = state != null ? _displayName(state) : 'there';
          final createdAt = state?.createdAt ?? DateTime.now();
          final submittedAt = state?.verificationSubmittedAt ?? DateTime.now();
          final effectiveRole = state?.role ?? role;
          final identityRequests = requests
              .where(
                (request) => request['review_type'] == 'identity_verification',
              )
              .toList();
          final credentialRequests = requests
              .where(
                (request) => request['review_type'] == 'instructor_credentials',
              )
              .toList();
          if (state?.isApproved == true &&
              identityRequests.isEmpty &&
              credentialRequests.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _redirectAfterApproval(context);
            });
            return const SafeArea(
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final hasAction = identityRequests.isNotEmpty ||
              (effectiveRole == 'instructor' && credentialRequests.isNotEmpty);

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 72,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasAction
                                    ? 'Action needed,\n$displayName'
                                    : 'Hang tight,\n$displayName',
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  height: 1.08,
                                  letterSpacing: -0.7,
                                  color: AppColors.foreground,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                hasAction
                                    ? 'Admin requested one more item before your review can continue.'
                                    : effectiveRole == 'instructor'
                                        ? "We're reviewing your documents so we can activate your account and continue instructor onboarding."
                                        : "We're reviewing your documents to get you on the road safely.",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  height: 1.45,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                              const SizedBox(height: 36),
                              _buildRequestedDocumentsCard(
                                context: context,
                                requests: identityRequests,
                                effectiveRole: effectiveRole,
                              ),
                              if (identityRequests.isNotEmpty)
                                const SizedBox(height: AppSpacing.xl),
                              if (effectiveRole == 'instructor' &&
                                  credentialRequests.isNotEmpty) ...[
                                _buildCredentialRequestCard(context),
                                const SizedBox(height: AppSpacing.xl),
                              ],
                              VerificationTimeline(
                                items: [
                                  VerificationTimelineItemData(
                                    title: 'Account Created',
                                    subtitle: _formatTimelineDate(createdAt),
                                    state:
                                        VerificationTimelineStepState.complete,
                                  ),
                                  VerificationTimelineItemData(
                                    title: 'ID Submitted',
                                    subtitle: _formatTimelineDate(submittedAt),
                                    state:
                                        VerificationTimelineStepState.complete,
                                  ),
                                  VerificationTimelineItemData(
                                    title: hasAction
                                        ? 'Waiting for Upload'
                                        : 'Admin Review',
                                    subtitle: hasAction
                                        ? 'Upload the requested item above'
                                        : 'Estimated wait: 2-4 hours',
                                    state:
                                        VerificationTimelineStepState.current,
                                    emphasisColor: AppColors.primary,
                                  ),
                                  const VerificationTimelineItemData(
                                    title: 'Start Driving',
                                    subtitle: 'Awaiting approval',
                                    state:
                                        VerificationTimelineStepState.upcoming,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.fromLTRB(20, 22, 20, 22),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary
                                      .withValues(alpha: 0.6),
                                  borderRadius:
                                      BorderRadius.circular(AppRadii.lg),
                                  boxShadow: AppShadows.subtle,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Icon(
                                        Icons.notifications_active_rounded,
                                        color: AppColors.primary,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.lg),
                                    Expanded(
                                      child: Text(
                                        hasAction
                                            ? 'After you upload, we will notify you when review is complete.'
                                            : "We'll send you a push notification as soon as your account is active.",
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w500,
                                          height: 1.45,
                                          color: AppColors.foreground,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppOutlineButton(
                      label: 'Logout',
                      onPressed: () {
                        unawaited(_handleReturnToSignIn(context));
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PendingReviewData {
  const _PendingReviewData({
    required this.state,
    required this.requests,
  });

  final IdentityVerificationState? state;
  final List<Map<String, dynamic>> requests;
}
