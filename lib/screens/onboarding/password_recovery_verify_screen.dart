import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_spacing.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/auth_back_button.dart';
import '../../widgets/keyboard_safe_scroll_view.dart';
import '../../widgets/otp_box_row.dart';

class PasswordRecoveryVerifyScreen extends StatefulWidget {
  const PasswordRecoveryVerifyScreen({
    super.key,
    required this.email,
  });

  final String email;

  @override
  State<PasswordRecoveryVerifyScreen> createState() =>
      _PasswordRecoveryVerifyScreenState();
}

class _PasswordRecoveryVerifyScreenState
    extends State<PasswordRecoveryVerifyScreen> with WidgetsBindingObserver {
  static const _otpLength = 6;
  static const _initialResendSeconds = 45;

  late final TextEditingController _otpController;
  late final FocusNode _focusNode;
  Timer? _timer;
  int _remainingSeconds = _initialResendSeconds;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _otpController = TextEditingController();
    _focusNode = FocusNode();
    _startTimer();
    _requestOtpFocus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _requestOtpFocus();
    }
  }

  void _requestOtpFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_focusNode);
      unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _remainingSeconds = _initialResendSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  String get _maskedEmail {
    final parts = widget.email.split('@');
    if (parts.length != 2) return widget.email;
    final local = parts[0];
    final domain = parts[1];
    final prefix = local.length <= 2 ? local : local.substring(0, 2);
    return '$prefix****@$domain';
  }

  Future<void> _handleVerify() async {
    final code = _otpController.text.trim();
    if (code.length != _otpLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the 6-digit code.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService.verifyPasswordRecoveryCode(
        email: widget.email,
        token: code,
      );
      if (!mounted) return;
      context.go(
        AppRoutes.newPassword,
        extra: {'email': widget.email},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResend() async {
    if (_remainingSeconds > 0) return;
    try {
      await SupabaseService.requestPasswordRecoveryCode(email: widget.email);
      if (!mounted) return;
      _otpController.clear();
      _startTimer();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recovery code resent.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to resend code: $e'),
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
      AppRoutes.forgotPassword,
      extra: {'email': widget.email},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: SafeArea(
          child: KeyboardSafeScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: AuthBackButton(
                    onPressed: _handleBack,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Verify Identity',
                  textAlign: TextAlign.center,
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
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                      color: AppColors.mutedForeground,
                    ),
                    children: [
                      const TextSpan(text: "We've sent a 6-digit code to "),
                      TextSpan(
                        text: _maskedEmail,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 74),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _requestOtpFocus,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      OtpBoxRow(code: _otpController.text),
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.01,
                          child: TextField(
                            controller: _otpController,
                            focusNode: _focusNode,
                            autofocus: true,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            enableSuggestions: false,
                            autocorrect: false,
                            maxLength: _otpLength,
                            showCursor: false,
                            cursorColor: Colors.transparent,
                            style: const TextStyle(color: Colors.transparent),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              counterText: '',
                              contentPadding: EdgeInsets.zero,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(_otpLength),
                            ],
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => _handleVerify(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 58),
                const Text(
                  "Didn't receive code?",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: _remainingSeconds == 0 ? _handleResend : null,
                  child: Text(
                    _remainingSeconds == 0
                        ? 'RESEND CODE'
                        : 'RESEND IN 0:${_remainingSeconds.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const Spacer(),
                AppPrimaryButton(
                  label: 'Verify & Continue',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _handleVerify,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
