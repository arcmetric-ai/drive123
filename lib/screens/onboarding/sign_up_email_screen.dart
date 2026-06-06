import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_spacing.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/auth_back_button.dart';
import '../../widgets/rounded_input_field.dart';

class SignUpEmailScreen extends StatefulWidget {
  const SignUpEmailScreen({
    super.key,
    this.initialEmail,
  });

  final String? initialEmail;

  @override
  State<SignUpEmailScreen> createState() => _SignUpEmailScreenState();
}

class _SignUpEmailScreenState extends State<SignUpEmailScreen> {
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

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final flowState = await SupabaseService.startSignUpFlow(email: email);
      if (!mounted) return;

      context.go(
        AppRoutes.signUpVerify,
        extra: flowState.toMap(),
      );
    } on AccountAlreadyExistsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That email already has an account. Log in instead.'),
          backgroundColor: AppColors.foreground,
        ),
      );
      context.go(AppRoutes.auth, extra: e.email);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to send confirmation link: $e'),
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
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuthBackButton(onPressed: () => context.go(AppRoutes.auth)),
                const SizedBox(height: 44),
                const Text(
                  'Create Account',
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
                  "Enter your email address and we'll send you a confirmation link.",
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
                  label: 'Continue',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _handleContinue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
