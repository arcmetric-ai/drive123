import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_spacing.dart';
import '../../models/identity_verification_state.dart';
import '../../services/launch_preferences.dart';
import '../../services/supabase_service.dart';
import '../../widgets/vertical_swipe_cta.dart';

class LearnerApprovalSuccessScreen extends StatefulWidget {
  const LearnerApprovalSuccessScreen({
    super.key,
    this.approvalToken,
  });

  final String? approvalToken;

  @override
  State<LearnerApprovalSuccessScreen> createState() =>
      _LearnerApprovalSuccessScreenState();
}

class _LearnerApprovalSuccessScreenState
    extends State<LearnerApprovalSuccessScreen> {
  bool _isCompleting = false;

  Future<void> _complete() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    final userId = SupabaseService.currentUser?.id;
    String? approvalToken = widget.approvalToken;

    if (approvalToken == null || approvalToken.isEmpty) {
      final state = await SupabaseService.getCurrentIdentityVerificationState();
      approvalToken = _approvalTokenFor(state);
    }

    if (userId != null && approvalToken != null && approvalToken.isNotEmpty) {
      await LaunchPreferences.markLearnerApprovalSuccessSeen(
        userId: userId,
        approvalToken: approvalToken,
      );
    }

    if (!mounted) return;
    context.go(AppRoutes.learnerQuestionnaire, extra: 'learner');
  }

  String? _approvalTokenFor(IdentityVerificationState? state) {
    if (state == null) return null;
    return state.verificationApprovedAt?.toUtc().toIso8601String() ??
        state.verificationStatus;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: _complete,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 34,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Swipe Up to start driving',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                  letterSpacing: -0.8,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Start your Drive Tutor journey today!!!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: IgnorePointer(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Transform.translate(
                            offset: const Offset(0, 12),
                            child: SvgPicture.asset(
                              'assets/images/cart.svg',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: VerticalSwipeCta(
                        onComplete: _complete,
                        height: 216,
                        width: 96,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
