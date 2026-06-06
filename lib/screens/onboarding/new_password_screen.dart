import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_spacing.dart';
import '../../models/signup_flow_state.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/password_strength_meter.dart';
import '../../widgets/rounded_input_field.dart';

class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({
    super.key,
    this.email,
    this.authUserId,
    this.flowToken,
    this.flow = 'recovery',
  });

  final String? email;
  final String? authUserId;
  final String? flowToken;
  final String flow;

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  bool get _isSignUpFlow => widget.flow == 'signup';

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isSignUpFlow) {
        final email = widget.email?.trim();
        final authUserId = widget.authUserId?.trim();
        final flowToken = widget.flowToken?.trim();
        if (email == null ||
            email.isEmpty ||
            authUserId == null ||
            authUserId.isEmpty ||
            flowToken == null ||
            flowToken.isEmpty) {
          throw Exception('Missing sign-up flow state. Please start again.');
        }

        final flowState = SignupFlowState(
          email: email,
          authUserId: authUserId,
          flowToken: flowToken,
        );

        await SupabaseService.completeSignUpPassword(
          flowState: flowState,
          newPassword: _passwordController.text,
        );
        await SupabaseService.signIn(
          email: email,
          password: _passwordController.text,
        );
        if (!mounted) return;
        await SupabaseService.ensureCurrentProfile();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password created. Choose your role to continue.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go(AppRoutes.roleSelection);
      } else {
        await SupabaseService.updatePassword(_passwordController.text);
        if (!mounted) return;
        await SupabaseService.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successfully. Please log in again.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go(AppRoutes.auth);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to reset password: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  _isSignUpFlow ? 'Create Password' : 'New Password',
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
                  _isSignUpFlow
                      ? 'Set a secure password for your new account.'
                      : 'Create a strong password to protect your account.',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                    color: AppColors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 56),
                RoundedInputField(
                  controller: _passwordController,
                  hintText: 'Create Password',
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter a password';
                    }
                    if (value.length < 8) {
                      return 'Use at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _passwordController,
                  builder: (context, value, _) {
                    return PasswordStrengthMeter(password: value.text);
                  },
                ),
                const SizedBox(height: 32),
                RoundedInputField(
                  controller: _confirmPasswordController,
                  hintText: 'Confirm Password',
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const Spacer(),
                AppPrimaryButton(
                  label: _isSignUpFlow ? 'Continue' : 'Reset Password',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _handleSubmitPassword,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
