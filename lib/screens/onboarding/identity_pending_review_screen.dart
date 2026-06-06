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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<IdentityVerificationState?>(
        future: SupabaseService.getCurrentIdentityVerificationState(),
        builder: (context, snapshot) {
          final state = snapshot.data;
          final displayName = state != null ? _displayName(state) : 'there';
          final createdAt = state?.createdAt ?? DateTime.now();
          final submittedAt = state?.verificationSubmittedAt ?? DateTime.now();
          final effectiveRole = state?.role ?? role;

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
                                'Hang tight,\n$displayName',
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
                                effectiveRole == 'instructor'
                                    ? "We're reviewing your documents so we can activate your account and continue instructor onboarding."
                                    : "We're reviewing your documents to get you on the road safely.",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  height: 1.45,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                              const SizedBox(height: 56),
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
                                  const VerificationTimelineItemData(
                                    title: 'Admin Review',
                                    subtitle: 'Estimated wait: 2-4 hours',
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
                                child: const Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Icon(
                                        Icons.notifications_active_rounded,
                                        color: AppColors.primary,
                                        size: 26,
                                      ),
                                    ),
                                    SizedBox(width: AppSpacing.lg),
                                    Expanded(
                                      child: Text(
                                        "We'll send you a push notification as soon as your account is active.",
                                        style: TextStyle(
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
