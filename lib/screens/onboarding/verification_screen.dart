import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_durations.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_spacing.dart';
import '../../widgets/numeric_keypad.dart';
import '../../widgets/otp_code_display.dart';
import '../../widgets/primary_stage_scaffold.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({
    super.key,
    required this.role,
    this.phoneNumber,
    this.nextRoute,
  });

  final String role;
  final String? phoneNumber;
  final String? nextRoute;

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  static const int _otpLength = 6;
  static const int _initialResendSeconds = 45;

  String _code = '';
  int _remainingSeconds = _initialResendSeconds;
  Timer? _resendTimer;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _remainingSeconds = _initialResendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  Future<void> _handleDigitPressed(String digit) async {
    if (_isSubmitting || _code.length >= _otpLength) return;

    setState(() => _code = '$_code$digit');

    if (_code.length == _otpLength) {
      await _submitCode();
    }
  }

  void _handleBackspace() {
    if (_isSubmitting || _code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  Future<void> _submitCode() async {
    if (_code.length != _otpLength) return;

    setState(() => _isSubmitting = true);
    await Future<void>.delayed(AppDurations.fast);
    if (!mounted) return;

    final nextRoute = widget.nextRoute;
    if (nextRoute != null && nextRoute.isNotEmpty) {
      context.go(nextRoute, extra: widget.role);
      return;
    }

    if (widget.role == 'instructor') {
      context.go(AppRoutes.instructorQuestionnaire, extra: widget.role);
    } else if (widget.role == 'learner') {
      context.go(AppRoutes.learnerQuestionnaire, extra: widget.role);
    } else {
      context.go(AppRoutes.roleSelection);
    }
  }

  void _handleResend() {
    if (_remainingSeconds > 0 || _isSubmitting) return;

    setState(() => _code = '');
    _startResendTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('A new verification code has been sent.'),
        backgroundColor: AppColors.foreground,
      ),
    );
  }

  String get _formattedPhoneNumber {
    final provided = widget.phoneNumber?.trim();
    if (provided != null && provided.isNotEmpty) return provided;
    return '+1 (555) 000-0000';
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryStageScaffold(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          children: [
            const SizedBox(height: 28),
            const Text(
              "Verify It's You",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primaryForeground,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Enter the 6-digit code sent to\n$_formattedPhoneNumber',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primaryForeground.withValues(alpha: 0.68),
                fontSize: 18,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
            const Spacer(flex: 2),
            OtpCodeDisplay(code: _code),
            const SizedBox(height: AppSpacing.xxl),
            TextButton(
              onPressed: _remainingSeconds == 0 ? _handleResend : null,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryForeground,
                disabledForegroundColor:
                    AppColors.primaryForeground.withValues(alpha: 0.76),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                _remainingSeconds > 0
                    ? 'RESEND CODE IN 0:${_remainingSeconds.toString().padLeft(2, '0')}'
                    : 'RESEND CODE',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.4,
                ),
              ),
            ),
            const Spacer(flex: 3),
            if (_isSubmitting)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.lg),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.primaryForeground,
                  ),
                ),
              ),
            NumericKeypad(
              onDigitPressed: _handleDigitPressed,
              onBackspacePressed: _handleBackspace,
            ),
          ],
        ),
      ),
    );
  }
}
