import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_spacing.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/brand_intro_header.dart';
import '../../widgets/labeled_text_field.dart';
import '../../widgets/section_divider.dart';
import '../../widgets/social_auth_button.dart';
import '../../constants/app_routes.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.initialEmail,
  });

  final String? initialEmail;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _signInFormKey = GlobalKey<FormState>();
  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();

  bool _isSignInLoading = false;
  bool _signInPasswordObscured = true;
  bool _showSignInPasswordStep = false;
  String? _signInErrorMessage;

  @override
  void initState() {
    super.initState();
    _signInEmailController.text = widget.initialEmail ?? '';
    _signInEmailController.addListener(_clearSignInErrorIfNeeded);
    _signInPasswordController.addListener(_clearSignInErrorIfNeeded);
  }

  @override
  void dispose() {
    _signInEmailController.removeListener(_clearSignInErrorIfNeeded);
    _signInPasswordController.removeListener(_clearSignInErrorIfNeeded);
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    super.dispose();
  }

  void _clearSignInErrorIfNeeded() {
    if (_signInErrorMessage == null || !mounted) return;
    setState(() => _signInErrorMessage = null);
  }

  Future<void> _handleContinueWithEmail() async {
    if (_signInErrorMessage != null) {
      setState(() => _signInErrorMessage = null);
    }
    if (!_showSignInPasswordStep) {
      final valid = _signInFormKey.currentState?.validate() ?? false;
      if (!valid) return;
      setState(() => _showSignInPasswordStep = true);
      return;
    }

    await _handleSignIn();
  }

  Future<void> _handleSignIn() async {
    if (!_signInFormKey.currentState!.validate()) return;

    setState(() => _isSignInLoading = true);

    try {
      final response = await SupabaseService.signIn(
        email: _signInEmailController.text.trim(),
        password: _signInPasswordController.text,
      );
      if (!mounted) return;

      final user = response.user;
      if (user == null) {
        throw Exception('Unable to sign in. Please try again.');
      }

      final destination = await SupabaseService.resolvePostAuthRoute(
        userId: user.id,
        metadataRole: user.userMetadata?['role'],
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Welcome back!'),
          backgroundColor: AppColors.success,
        ),
      );

      context.go(destination);
    } on AuthException catch (e) {
      if (!mounted) return;
      final message = e.message.toLowerCase();
      final isCredentialIssue = message.contains('invalid login credentials') ||
          message.contains('invalid credentials') ||
          message.contains('email not confirmed') ||
          message.contains('email or password') ||
          message.contains('user not found');
      setState(() {
        _signInErrorMessage = isCredentialIssue
            ? "Those credentials don't match an account. Try again or sign up."
            : 'Unable to sign in right now. Please try again.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _signInErrorMessage = 'Sign in failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSignInLoading = false);
      }
    }
  }

  void _showUnavailableSocialMessage(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$provider sign in is not wired up yet.'),
        backgroundColor: AppColors.foreground,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: _SignInView(
            formKey: _signInFormKey,
            emailController: _signInEmailController,
            passwordController: _signInPasswordController,
            showPasswordStep: _showSignInPasswordStep,
            passwordObscured: _signInPasswordObscured,
            isLoading: _isSignInLoading,
            errorMessage: _signInErrorMessage,
            onTogglePassword: () => setState(
              () => _signInPasswordObscured = !_signInPasswordObscured,
            ),
            onContinue: _handleContinueWithEmail,
            onGooglePressed: () => _showUnavailableSocialMessage('Google'),
            onApplePressed: () => _showUnavailableSocialMessage('Apple'),
            onForgotPassword: () => context.go(
              AppRoutes.forgotPassword,
              extra: _signInEmailController.text.trim(),
            ),
            onSwitchToSignUp: () => context.go(
              AppRoutes.signUpEmail,
              extra: {'email': _signInEmailController.text.trim()},
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInView extends StatelessWidget {
  const _SignInView({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.showPasswordStep,
    required this.passwordObscured,
    required this.isLoading,
    required this.errorMessage,
    required this.onTogglePassword,
    required this.onContinue,
    required this.onGooglePressed,
    required this.onApplePressed,
    required this.onForgotPassword,
    required this.onSwitchToSignUp,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool showPasswordStep;
  final bool passwordObscured;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onTogglePassword;
  final VoidCallback onContinue;
  final VoidCallback onGooglePressed;
  final VoidCallback onApplePressed;
  final VoidCallback onForgotPassword;
  final VoidCallback onSwitchToSignUp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BrandIntroHeader(
          title: 'Welcome to\nDrive Tutor',
          subtitle: "Your journey to the driver's seat starts here.",
          badgeSize: 72,
          badgeBackgroundColor: AppColors.primaryBlue,
          badgePadding: EdgeInsets.all(9),
          badgeContentScale: 1.35,
        ),
        const SizedBox(height: 36),
        Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LabeledTextField(
                label: 'Email Address',
                controller: emailController,
                hintText: 'name@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: showPasswordStep
                    ? TextInputAction.next
                    : TextInputAction.done,
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
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: showPasswordStep
                    ? Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.lg),
                        child: LabeledTextField(
                          label: 'Password',
                          controller: passwordController,
                          hintText: 'Enter your password',
                          obscureText: passwordObscured,
                          textInputAction: TextInputAction.done,
                          suffixIcon: IconButton(
                            onPressed: onTogglePassword,
                            icon: Icon(
                              passwordObscured
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                          validator: (value) {
                            if (!showPasswordStep) return null;
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            return null;
                          },
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (showPasswordStep)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onForgotPassword,
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              if (errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _InlineAuthError(
                  message: errorMessage!,
                  onSignUpPressed: onSwitchToSignUp,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              AppPrimaryButton(
                label: showPasswordStep ? 'Log In' : 'Continue with Email',
                isLoading: isLoading,
                onPressed: isLoading ? null : onContinue,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionDivider(label: 'or'),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: SocialAuthButton(
                label: 'Google',
                leading: const _GoogleMark(),
                onPressed: onGooglePressed,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SocialAuthButton(
                label: 'Apple',
                leading: const Icon(
                  Icons.apple,
                  size: 24,
                  color: AppColors.foreground,
                ),
                onPressed: onApplePressed,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xl),
          child: Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mutedForeground,
                ),
                children: [
                  const TextSpan(text: "Don't have an account? "),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      onTap: onSwitchToSignUp,
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 14,
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
        ),
      ],
    );
  }
}

class _InlineAuthError extends StatelessWidget {
  const _InlineAuthError({
    required this.message,
    required this.onSignUpPressed,
  });

  final String message;
  final VoidCallback onSignUpPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3C6C6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          GestureDetector(
            onTap: onSignUpPressed,
            child: const Text(
              'Sign up instead',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: Color(0xFF4285F4),
      ),
    );
  }
}
