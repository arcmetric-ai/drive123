import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_spacing.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_primary_button.dart';
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
  bool _isSaving = false;

  Future<void> _handleConfirmSelection() async {
    final role = _selectedRole;
    if (role == null || _isSaving) return;

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
                    const SizedBox(height: 20),
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
                      illustrationBackgroundColor: const Color(0xFFFFF9E6),
                      illustration: SvgPicture.asset(
                        'assets/icons/learner.svg',
                      ),
                      isSelected: _selectedRole == 'learner',
                      onTap: () => setState(() => _selectedRole = 'learner'),
                      isEnabled: !_isSaving,
                    ),
                    const SizedBox(height: 18),
                    SelectionOptionCard(
                      title: "I'm an Instructor",
                      subtitle:
                          'I am a certified driving instructor and will apply through the website.',
                      illustrationBackgroundColor: const Color(0xFFF7F7FB),
                      illustration: SvgPicture.asset(
                        'assets/icons/instructor.svg',
                      ),
                      isSelected: _selectedRole == 'instructor',
                      onTap: () => setState(() => _selectedRole = 'instructor'),
                      isEnabled: !_isSaving,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    AppPrimaryButton(
                      label: 'Confirm Selection',
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
