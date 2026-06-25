import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
    this.role = 'learner',
    this.learnerAccountType = 'learner',
  });

  final String? initialEmail;
  final String role;
  final String learnerAccountType;

  @override
  State<SignUpEmailScreen> createState() => _SignUpEmailScreenState();
}

class _SignUpEmailScreenState extends State<SignUpEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _isLoading = false;
  bool _acceptedPolicies = false;

  bool get _isGuardian => widget.learnerAccountType == 'guardian';

  String get _consentTitle {
    if (_isGuardian) {
      return 'I confirm I am the parent or legal guardian creating this account for a 16 or 17-year-old learner.';
    }
    return 'I am 18 or older and agree to Drive Tutor account and verification terms.';
  }

  String get _consentBody {
    if (_isGuardian) {
      return 'I will manage consent, verification, notifications, and lesson requests for this ward. This account is not for an adult learner or another purpose.';
    }
    final roleLabel = _isGuardian ? 'guardian-managed learner' : widget.role;
    return 'By continuing, I accept the required Drive Tutor policies for this $roleLabel account, including terms, privacy, data consent, safety, community guidelines, and identity/licence verification consent.';
  }

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
    if (!_acceptedPolicies) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review and accept the required policies to continue.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final flowState = await SupabaseService.startSignUpFlow(
        email: email,
        role: widget.role,
        learnerAccountType: widget.learnerAccountType,
      );
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

  Future<void> _openPolicy(String path) async {
    final uri = Uri.parse('https://www.drivetutor.ca/$path');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuthBackButton(
                        onPressed: () => context.go(AppRoutes.learnerAccountType),
                      ),
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
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CheckboxListTile(
                              value: _acceptedPolicies,
                              onChanged: _isLoading
                                  ? null
                                  : (value) => setState(
                                        () => _acceptedPolicies = value ?? false,
                                      ),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                _consentTitle,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                  color: AppColors.foreground,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  _consentBody,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      _openPolicy('terms-and-conditions'),
                                  child: const Text('Terms'),
                                ),
                                TextButton(
                                  onPressed: () => _openPolicy('privacy-policy'),
                                  child: const Text('Privacy'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _openPolicy('data-consent-policy'),
                                  child: const Text('Data Consent'),
                                ),
                                TextButton(
                                  onPressed: () => _openPolicy('safety-policy'),
                                  child: const Text('Safety'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _openPolicy('community-guidelines'),
                                  child: const Text('Community'),
                                ),
                                TextButton(
                                  onPressed: () => _openPolicy(
                                    _isGuardian
                                        ? 'guardian-consent'
                                        : 'identity-verification-consent',
                                  ),
                                  child: Text(
                                    _isGuardian
                                        ? 'Guardian Consent'
                                        : 'Verification Consent',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.background,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.foreground.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: AppPrimaryButton(
                  label: 'Continue',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _handleContinue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
