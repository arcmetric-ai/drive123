import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../services/supabase_service.dart';

class LearningFocusScreen extends StatefulWidget {
  final String role;

  const LearningFocusScreen({super.key, required this.role});

  @override
  State<LearningFocusScreen> createState() => _LearningFocusScreenState();
}

class _LearningFocusScreenState extends State<LearningFocusScreen> {
  String? _selectedFocus;
  bool _isSubmitting = false;

  final List<_FocusOption> _options = const [
    _FocusOption(
      value: 'G2',
      title: 'G2 Road Test',
      description: 'For new drivers preparing for their G2 road exam.',
      icon: Icons.directions_car,
    ),
    _FocusOption(
      value: 'G',
      title: 'G Road Test',
      description: 'Step up to full licence readiness with highway training.',
      icon: Icons.alt_route,
    ),
    _FocusOption(
      value: 'PR',
      title: 'Practice Sessions',
      description: 'Brush up on specific skills or gain extra confidence.',
      icon: Icons.emoji_events,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingFocus();
  }

  Future<void> _handleContinue() async {
    if (_selectedFocus == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a training focus to continue.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in again to save your focus.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      await SupabaseService.upsertLearnerProfile(
        userId: userId,
        learningFocus: _selectedFocus,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to save your focus: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      setState(() => _isSubmitting = false);
      return;
    }

    if (!mounted) return;

    setState(() => _isSubmitting = false);
    context.go(AppRoutes.home, extra: {'focus': _selectedFocus});
  }

  Future<void> _loadExistingFocus() async {
    if (widget.role != 'learner') {
      return;
    }

    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      return;
    }

    try {
      final detail = await SupabaseService.getLearnerProfileDetail(userId);
      if (!mounted) return;
      final focus = detail?['learning_focus'] as String?;
      if (focus != null && focus.isNotEmpty) {
        setState(() => _selectedFocus = focus);
      }
    } catch (_) {
      // ignore; user can still pick a focus
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
      appBar: AppBar(
        title: const Text('Choose Your Focus'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What are you preparing for?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select the licence or practice type you need help with. We’ll show you instructors who specialise in that area.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: _options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final option = _options[index];
                    final isSelected = _selectedFocus == option.value;
                    return _FocusTile(
                      option: option,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() => _selectedFocus = option.value);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Continue to Home',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusOption {
  final String value;
  final String title;
  final String description;
  final IconData icon;

  const _FocusOption({
    required this.value,
    required this.title,
    required this.description,
    required this.icon,
  });
}

class _FocusTile extends StatelessWidget {
  final _FocusOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _FocusTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue.withAlpha((0.12 * 255).round())
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withAlpha((0.15 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                option.icon,
                color: AppColors.primaryBlue,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    option.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isSelected ? 1 : 0,
              child: const Icon(
                Icons.check_circle,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
