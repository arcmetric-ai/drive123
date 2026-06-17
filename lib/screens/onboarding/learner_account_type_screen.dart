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

  void _handleContinue() {
    final selectedType = _selectedType;
    if (selectedType == null) return;

    context.go(
      AppRoutes.signUpEmail,
      extra: {
        'role': 'learner',
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
                        onTap: () => setState(() => _selectedType = 'learner'),
                      ),
                      const SizedBox(height: 14),
                      SelectionOptionCard(
                        title: 'Guardian',
                        subtitle:
                            'I am signing up for a child learner and will receive all account notifications.',
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
                      const Spacer(),
                      const SizedBox(height: AppSpacing.lg),
                      AppPrimaryButton(
                        label: 'Continue',
                        onPressed:
                            _selectedType == null ? null : _handleContinue,
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
