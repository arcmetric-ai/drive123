import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_spacing.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/auth_back_button.dart';
import '../../widgets/selection_option_card.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  static final Uri _instructorApplicationUrl =
      Uri.parse('https://www.drivetutor.ca/instructor/apply');

  String? _selectedRole;
  bool _acceptedLearnerPolicies = false;
  bool _isSaving = false;

  Future<void> _openPolicy(String path) async {
    final uri = Uri.parse('https://www.drivetutor.ca/$path');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _handleConfirmSelection() async {
    final role = _selectedRole;
    if (role == null || _isSaving) return;
    if (role == 'learner' && !_acceptedLearnerPolicies) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Review and accept the required policies to continue.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (role == 'instructor') {
        final launched = await launchUrl(
          _instructorApplicationUrl,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          throw Exception('Unable to open the instructor application page.');
        }
        return;
      }

      final user = SupabaseService.currentUser;
      if (user == null) {
        if (!mounted) return;
        context.go(AppRoutes.learnerAccountType);
        return;
      }

      await SupabaseService.assignUserRole(
        userId: user.id,
        role: role,
      );
      if (!mounted) return;

      context.go(AppRoutes.learnerQuestionnaire, extra: role);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save role: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AuthBackButton(
                      onPressed: () => context.go(AppRoutes.accountEntry),
                    ),
                    const SizedBox(height: 34),
                    const Text(
                      'How will you use\nDrive Tutor?',
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
                      'Choose your role to get started.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        height: 1.45,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 40),
                    SelectionOptionCard(
                      title: "I'm a Learner",
                      subtitle:
                          'I want to learn to drive and get my Ontario G2 or G license.',
                      illustrationBackgroundColor: const Color(0xFFF2FBF7),
                      illustration: SvgPicture.asset(
                        'assets/images/role_learner.svg',
                      ),
                      isSelected: _selectedRole == 'learner',
                      onTap: () => setState(() {
                        _selectedRole = 'learner';
                      }),
                      isEnabled: !_isSaving,
                    ),
                    const SizedBox(height: 18),
                    SelectionOptionCard(
                      title: "I'm an Instructor",
                      subtitle:
                          'Instructor accounts are created and verified on our website first.',
                      illustrationBackgroundColor: const Color(0xFFF3F7FF),
                      illustration: SvgPicture.asset(
                        'assets/images/role_instructor.svg',
                      ),
                      isSelected: _selectedRole == 'instructor',
                      onTap: () => setState(() => _selectedRole = 'instructor'),
                      isEnabled: !_isSaving,
                    ),
                    if (_selectedRole == 'instructor') ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FF),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.primaryBlue,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Instructor access is login-only in the app.',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.foreground,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Apply, verify your documents, and complete your instructor profile on drivetutor.ca. After approval, return here and sign in.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      height: 1.35,
                                      color: AppColors.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_selectedRole == 'learner') ...[
                      const SizedBox(height: 18),
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
                              value: _acceptedLearnerPolicies,
                              onChanged: _isSaving
                                  ? null
                                  : (value) => setState(
                                        () => _acceptedLearnerPolicies =
                                            value ?? false,
                                      ),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text(
                                'I agree to Drive Tutor learner account, safety, privacy, data consent, and identity/licence verification policies.',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                  color: AppColors.foreground,
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
                                  onPressed: () =>
                                      _openPolicy('privacy-policy'),
                                  child: const Text('Privacy'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _openPolicy('data-consent-policy'),
                                  child: const Text('Data Consent'),
                                ),
                                TextButton(
                                  onPressed: () => _openPolicy(
                                      'identity-verification-consent'),
                                  child: const Text('Verification'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    AppPrimaryButton(
                      label: _selectedRole == 'instructor'
                          ? 'Go to website'
                          : 'Confirm Selection',
                      isLoading: _isSaving,
                      onPressed: _selectedRole == null || _isSaving
                          ? null
                          : _handleConfirmSelection,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
