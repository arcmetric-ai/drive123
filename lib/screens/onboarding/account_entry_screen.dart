import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_spacing.dart';
import '../../widgets/app_outline_button.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/brand_intro_header.dart';

class AccountEntryScreen extends StatelessWidget {
  const AccountEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BrandIntroHeader(
                title: 'Drive Tutor',
                subtitle: 'Manage lessons, requests, and your driving journey.',
                badgeSize: 88,
                badgeBackgroundColor: AppColors.primaryBlue,
                badgeContentScale: 1.4,
              ),
              const Spacer(),
              AppPrimaryButton(
                label: 'Create an Account',
                onPressed: () => context.go(AppRoutes.roleSelection),
              ),
              const SizedBox(height: AppSpacing.md),
              AppOutlineButton(
                label: 'I Have an Account',
                onPressed: () => context.go(AppRoutes.auth),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
