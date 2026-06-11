import 'package:flutter/material.dart';
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
                        illustrationBackgroundColor: const Color(0xFFFFF9E6),
                        illustration: Icon(
                          Icons.person_rounded,
                          size: 42,
                          color: _selectedType == 'learner'
                              ? AppColors.primary
                              : AppColors.mutedForeground,
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
                        illustrationBackgroundColor: const Color(0xFFF7F7FB),
                        illustration: Icon(
                          Icons.supervisor_account_rounded,
                          size: 42,
                          color: _selectedType == 'guardian'
                              ? AppColors.primary
                              : AppColors.mutedForeground,
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
