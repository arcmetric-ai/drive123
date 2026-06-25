import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_spacing.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/auth_back_button.dart';
import '../../widgets/keyboard_safe_scroll_view.dart';
import '../../widgets/rounded_input_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.initialEmail,
  });

  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      await SupabaseService.requestPasswordRecoveryCode(email: email);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recovery code sent to your email.'),
          backgroundColor: AppColors.success,
        ),
      );

      context.go(
        AppRoutes.passwordRecoveryVerify,
        extra: {'email': email},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to send code: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: KeyboardSafeScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuthBackButton(onPressed: () => context.go(AppRoutes.auth)),
                const SizedBox(height: 44),
                const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1.08,
                    letterSpacing: -0.7,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  "Enter your email address and we'll send you a 6-digit recovery code.",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 52),
                RoundedInputField(
                  controller: _emailController,
                  hintText: 'EMAIL ADDRESS',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const Spacer(),
                AppPrimaryButton(
                  label: 'Send Code',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _handleSendCode,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
