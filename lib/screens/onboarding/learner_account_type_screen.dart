import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_spacing.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/auth_back_button.dart';
import '../../widgets/selection_option_card.dart';

class LearnerAccountTypeScreen extends StatefulWidget {
  const LearnerAccountTypeScreen({super.key});

  @override
  State<LearnerAccountTypeScreen> createState() =>
      _LearnerAccountTypeScreenState();
}

class _LearnerAccountTypeScreenState extends State<LearnerAccountTypeScreen> {
  String? _selectedType;
  bool _guardianPurposeConfirmed = false;

  bool get _isGuardianSelected => _selectedType == 'guardian';

  bool get _canContinue =>
      _selectedType != null &&
      (!_isGuardianSelected || _guardianPurposeConfirmed);

  void _handleContinue() {
    final selectedType = _selectedType;
    if (selectedType == null) return;

    if (selectedType == 'guardian' && !_guardianPurposeConfirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Confirm this guardian account is for a 16 or 17-year-old ward.',
          ),
        ),
      );
      return;
    }

    final role = selectedType == 'guardian' ? 'guardian' : 'learner';
    context.go(
      AppRoutes.signUpEmail,
      extra: {
        'role': role,
        'learnerAccountType': selectedType,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuthBackButton(
                        onPressed: () => context.go(AppRoutes.roleSelection),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Who is this\naccount for?',
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
                        'Learners 16 or 17 need a guardian to create and manage the account.',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SelectionOptionCard(
                        title: 'Learner',
                        subtitle:
                            'I am 18 or older and will manage my own lessons and notifications.',
                        illustrationSize: 86,
                        cardPadding: const EdgeInsets.all(14),
                        titleFontSize: 20,
                        subtitleFontSize: 14,
                        titleTopPadding: 4,
                        illustrationBackgroundColor: const Color(0xFFF2FBF7),
                        illustration: SvgPicture.asset(
                          'assets/images/role_learner.svg',
                        ),
                        isSelected: _selectedType == 'learner',
                        onTap: () => setState(() {
                          _selectedType = 'learner';
                          _guardianPurposeConfirmed = false;
                        }),
                      ),
                      const SizedBox(height: 14),
                      SelectionOptionCard(
                        title: 'Guardian',
                        subtitle:
                            'I am a parent or legal guardian creating this account for a 16 or 17-year-old ward.',
                        illustrationSize: 86,
                        cardPadding: const EdgeInsets.all(14),
                        titleFontSize: 20,
                        subtitleFontSize: 14,
                        titleTopPadding: 4,
                        illustrationBackgroundColor: const Color(0xFFF3F7FF),
                        illustration: SvgPicture.asset(
                          'assets/images/role_guardian.svg',
                        ),
                        isSelected: _selectedType == 'guardian',
                        onTap: () => setState(() => _selectedType = 'guardian'),
                      ),
                      if (_isGuardianSelected) ...[
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.32),
                            ),
                          ),
                          child: CheckboxListTile(
                            value: _guardianPurposeConfirmed,
                            onChanged: (value) => setState(
                              () => _guardianPurposeConfirmed = value ?? false,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: AppColors.primary,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            title: const Text(
                              'I confirm I am creating this guardian account for my 16 or 17-year-old ward and will manage consent, verification, notifications, and lesson requests for them. This account is not for an adult learner or another purpose.',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                                color: AppColors.foreground,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      const SizedBox(height: AppSpacing.lg),
                      AppPrimaryButton(
                        label: 'Continue',
                        onPressed: _canContinue ? _handleContinue : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
