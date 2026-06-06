import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/selection_option_card.dart';
import '../../services/supabase_service.dart';

class LearningFocusScreen extends StatefulWidget {
  const LearningFocusScreen({super.key, required this.role});

  final String role;

  @override
  State<LearningFocusScreen> createState() => _LearningFocusScreenState();
}

class _LearningFocusScreenState extends State<LearningFocusScreen> {
  static const _options = [
    _FocusOption(
      value: 'G2',
      title: 'G2 Preparation',
      description: 'Beginner training for road test.',
      icon: Icons.sell_rounded,
    ),
    _FocusOption(
      value: 'G',
      title: 'G License Preparation',
      description: 'Advanced highway & city skills.',
      icon: Icons.star_rounded,
    ),
    _FocusOption(
      value: 'PR',
      title: 'Refresher Session',
      description: 'Polish skills or build confidence.',
      icon: Icons.sync_rounded,
    ),
  ];

  String? _selectedFocus;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadExistingFocus();
  }

  Future<void> _loadExistingFocus() async {
    if (widget.role != 'learner') return;
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      final detail = await SupabaseService.getLearnerProfileDetail(userId);
      if (!mounted) return;
      final focus = detail?['learning_focus'] as String?;
      if (focus != null && focus.isNotEmpty) {
        setState(() => _selectedFocus = focus);
      } else {
        setState(() => _selectedFocus = 'G2');
      }
    } catch (_) {
      if (mounted && _selectedFocus == null) {
        setState(() => _selectedFocus = 'G2');
      }
    }
  }

  Future<void> _handleContinue() async {
    if (_selectedFocus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose your driving goal to continue.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in again to continue.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await SupabaseService.upsertLearnerProfile(
        userId: userId,
        learningFocus: _selectedFocus,
      );
      if (!mounted) return;
      context.go(AppRoutes.home, extra: {'focus': _selectedFocus});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save your driving goal: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role != 'learner') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(AppRoutes.instructorHome);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What is your\ndriving goal?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "We'll tailor your learning path based on this.",
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.4,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 28),
                    ..._options.map((option) {
                      final isSelected = _selectedFocus == option.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: SelectionOptionCard(
                          title: option.title,
                          subtitle: option.description,
                          isSelected: isSelected,
                          illustrationSize: 86,
                          cardPadding: const EdgeInsets.all(14),
                          titleFontSize: 20,
                          subtitleFontSize: 14,
                          titleTopPadding: 4,
                          illustrationBackgroundColor: const Color(0xFFFCF7DE),
                          illustration: Center(
                            child: Icon(
                              option.icon,
                              size: 38,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.mutedForeground,
                            ),
                          ),
                          onTap: () => setState(() {
                            _selectedFocus = option.value;
                          }),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: AppPrimaryButton(
                label: 'Confirm Goal',
                onPressed: _isSubmitting ? null : _handleContinue,
                isLoading: _isSubmitting,
                height: 64,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusOption {
  const _FocusOption({
    required this.value,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String value;
  final String title;
  final String description;
  final IconData icon;
}
