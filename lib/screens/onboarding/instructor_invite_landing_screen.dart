import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../services/instructor_referral_service.dart';
import '../../services/supabase_service.dart';

class InstructorInviteLandingScreen extends StatefulWidget {
  const InstructorInviteLandingScreen({super.key, required this.code});

  final String code;

  @override
  State<InstructorInviteLandingScreen> createState() =>
      _InstructorInviteLandingScreenState();
}

class _InstructorInviteLandingScreenState
    extends State<InstructorInviteLandingScreen> {
  bool _isClaiming = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _handleInvite();
  }

  Future<void> _handleInvite() async {
    await InstructorReferralService.savePendingCode(widget.code);

    if (SupabaseService.currentUser == null) {
      if (!mounted) return;
      setState(() {
        _isClaiming = false;
        _message = 'Create or sign in to continue with this instructor.';
      });
      return;
    }

    try {
      await InstructorReferralService.claimPendingCodeIfAvailable();
      if (!mounted) return;
      setState(() {
        _isClaiming = false;
        _message = 'Instructor connected.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isClaiming = false;
        _message =
            'Code saved. Finish your learner profile, add availability, and upload a profile photo to connect with this instructor.';
      });
    }
  }

  Future<void> _continue() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      context.go(AppRoutes.accountEntry);
      return;
    }
    final pendingCode = await InstructorReferralService.pendingCode();
    final verificationState =
        await SupabaseService.getIdentityVerificationState(user.id);
    if (pendingCode != null &&
        verificationState?.onboardingStage ==
            SupabaseService.onboardingStageQuestionnaireComplete) {
      if (!mounted) return;
      context.go(AppRoutes.learnerReferralProfilePhoto);
      return;
    }
    final destination = await SupabaseService.resolvePostAuthRoute(
      userId: user.id,
      metadataRole: user.userMetadata?['role'],
    );
    if (!mounted) return;
    context.go(destination);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.qr_code_2_rounded,
                color: AppColors.primary,
                size: 58,
              ),
              const SizedBox(height: 20),
              const Text(
                'Drive Tutor invite',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _message ?? 'Checking your invite...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.mutedForeground,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              if (_isClaiming)
                const Center(child: CircularProgressIndicator())
              else ...[
                FilledButton(
                  onPressed: _continue,
                  child: Text(
                    SupabaseService.currentUser == null
                        ? 'Create or Sign In'
                        : 'Continue',
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go(AppRoutes.accountEntry),
                  child: const Text('Choose a different account'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
