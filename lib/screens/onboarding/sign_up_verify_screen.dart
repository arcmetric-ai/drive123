import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_spacing.dart';
import '../../models/signup_flow_state.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/auth_back_button.dart';

class SignUpVerifyScreen extends StatefulWidget {
  const SignUpVerifyScreen({
    super.key,
    required this.flowState,
  });

  final SignupFlowState flowState;

  @override
  State<SignUpVerifyScreen> createState() => _SignUpVerifyScreenState();
}

class _SignUpVerifyScreenState extends State<SignUpVerifyScreen> {
  bool _isLoading = false;

  String get _maskedEmail {
    final parts = widget.flowState.email.split('@');
    if (parts.length != 2) return widget.flowState.email;
    final local = parts[0];
    final domain = parts[1];
    final prefix = local.length <= 2 ? local : local.substring(0, 2);
    return '$prefix****@$domain';
  }

  Future<void> _handleContinue() async {
    setState(() => _isLoading = true);
    try {
      if (!mounted) return;
      final isConfirmed = await SupabaseService.checkSignUpConfirmation(
        flowState: widget.flowState,
      );
      if (!mounted) return;

      if (isConfirmed) {
        _continueToPassword();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'That email is not confirmed yet. Confirm it and try again.'),
          backgroundColor: AppColors.foreground,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to continue: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _continueToPassword() {
    if (!mounted) return;
    context.go(
      AppRoutes.newPassword,
      extra: {
        ...widget.flowState.toMap(),
        'flow': 'signup',
      },
    );
  }

  Future<void> _handleResend() async {
    try {
      final refreshedFlow = await SupabaseService.startSignUpFlow(
        email: widget.flowState.email,
        role: widget.flowState.role,
        learnerAccountType: widget.flowState.learnerAccountType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Confirmation link sent again.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go(
        AppRoutes.signUpVerify,
        extra: refreshedFlow.toMap(),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to resend confirmation link: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _handleBack() {
    if (Navigator.of(context).canPop()) {
      context.pop();
      return;
    }

    context.go(
      AppRoutes.signUpEmail,
      extra: {'email': widget.flowState.email},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthBackButton(onPressed: _handleBack),
              const SizedBox(height: 28),
              const Text(
                'Check Your Email',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                  letterSpacing: -0.7,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                    color: AppColors.mutedForeground,
                  ),
                  children: [
                    const TextSpan(
                      text: "We've sent a confirmation link to ",
                    ),
                    TextSpan(
                      text: _maskedEmail,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                    const TextSpan(
                      text:
                          '. Open that link to confirm your account, then return here to continue.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FF),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What happens next',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.foreground,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '1. Open the email from Drive Tutor.\n2. Tap the confirmation link on any device.\n3. Return here and tap "I Confirmed My Email".',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.55,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              AppPrimaryButton(
                label: 'I Confirmed My Email',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _handleContinue,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: _handleResend,
                  child: const Text(
                    'Resend Confirmation Link',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
