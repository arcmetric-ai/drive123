import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../constants/app_radii.dart';
import '../../constants/app_spacing.dart';
import '../../models/instructor_billing.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_primary_button.dart';

class InstructorBillingScreen extends StatefulWidget {
  const InstructorBillingScreen({super.key});

  @override
  State<InstructorBillingScreen> createState() =>
      _InstructorBillingScreenState();
}

class _InstructorBillingScreenState extends State<InstructorBillingScreen>
    with WidgetsBindingObserver {
  static final Uri _activationUrl =
      Uri.parse('https://www.drivetutor.ca/instructor/activate');

  late Future<_BillingState> _stateFuture;
  bool _isOpeningActivation = false;
  bool _awaitingActivationReturn = false;
  bool _isCheckingActivation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _stateFuture = _loadState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingActivationReturn) {
      _checkActivationResult();
    }
  }

  Future<_BillingState> _loadState() async {
    final plans = await SupabaseService.getInstructorBillingPlans();
    final entitlement =
        await SupabaseService.getCurrentInstructorBillingEntitlement();
    return _BillingState(plans: plans, entitlement: entitlement);
  }

  Future<void> _refresh() async {
    setState(() {
      _stateFuture = _loadState();
    });
    final state = await _stateFuture;
    if (!mounted) return;
    if (state.entitlement?.isActive == true) {
      context.go(AppRoutes.instructorHome);
    }
  }

  Future<void> _checkActivationResult() async {
    if (_isCheckingActivation) return;
    _isCheckingActivation = true;
    if (mounted) setState(() {});

    try {
      for (var attempt = 0; attempt < 8; attempt += 1) {
        final entitlement =
            await SupabaseService.getCurrentInstructorBillingEntitlement();
        if (!mounted) return;

        if (entitlement?.isActive == true) {
          _awaitingActivationReturn = false;
          context.go(AppRoutes.instructorHome);
          return;
        }

        if (attempt < 7) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }

      await _refresh();
    } finally {
      _isCheckingActivation = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _openActivationWebsite() async {
    if (_isOpeningActivation) return;
    setState(() => _isOpeningActivation = true);
    try {
      _awaitingActivationReturn = true;
      final launched = await launchUrl(
        _activationUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _awaitingActivationReturn = false;
        throw Exception('Unable to open the activation page.');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open activation: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isOpeningActivation = false);
    }
  }

  String _dailyRate(InstructorBillingPlan plan) {
    final amountPerDay = (plan.amountCents / plan.accessDays) / 100;
    final whole = amountPerDay == amountPerDay.roundToDouble();
    final amount = whole
        ? amountPerDay.toStringAsFixed(0)
        : amountPerDay.toStringAsFixed(2);
    final currency = plan.currency.trim().toUpperCase();
    final prefix = currency == 'CAD'
        ? 'CA\$'
        : currency == 'USD'
            ? 'US\$'
            : '$currency ';
    return '$prefix$amount/day';
  }

  String _accessLabel(InstructorBillingPlan plan) {
    if (plan.accessDays == 1) return '1 day of instructor access';
    if (plan.billingInterval == 'month') return '30 days of instructor access';
    if (plan.billingInterval == 'year') return '365 days of instructor access';
    return '${plan.accessDays} days of instructor access';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FutureBuilder<_BillingState>(
          future: _stateFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _BillingErrorState(
                error: snapshot.error.toString(),
                onRetry: _refresh,
              );
            }

            final state = snapshot.data ?? const _BillingState();
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.xl,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Instructor Pass',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: AppColors.foreground,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const Text(
                              'Choose a pass to unlock instructor tools after approval.',
                              style: TextStyle(
                                color: AppColors.mutedForeground,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  if (state.entitlement != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _EntitlementBanner(entitlement: state.entitlement!),
                  ],
                  if (_awaitingActivationReturn || _isCheckingActivation) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _ActivationStatusBanner(
                      isChecking: _isCheckingActivation,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  for (final plan in state.plans) ...[
                    _PassCard(
                      plan: plan,
                      dailyRate: _dailyRate(plan),
                      accessLabel: _accessLabel(plan),
                      isLoading: _isOpeningActivation,
                      onPressed: _openActivationWebsite,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  AppPrimaryButton(
                    label: _isCheckingActivation
                        ? 'Checking activation...'
                        : 'Refresh activation',
                    onPressed: _refresh,
                    height: 52,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: _signOut,
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    await SupabaseService.signOut();
    if (!mounted) return;
    context.go(AppRoutes.auth);
  }
}

class _PassCard extends StatelessWidget {
  const _PassCard({
    required this.plan,
    required this.dailyRate,
    required this.accessLabel,
    required this.isLoading,
    required this.onPressed,
  });

  final InstructorBillingPlan plan;
  final String dailyRate;
  final String accessLabel;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isBestValue = plan.billingInterval == 'year';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: isBestValue ? AppColors.primary : AppColors.border,
          width: isBestValue ? 1.4 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.displayName,
                        style: const TextStyle(
                          color: AppColors.foreground,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        accessLabel,
                        style: const TextStyle(
                          color: AppColors.mutedForeground,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isBestValue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: const Text(
                      'Best value',
                      style: TextStyle(
                        color: AppColors.accentForeground,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan.priceLabel,
                  style: const TextStyle(
                    color: AppColors.foreground,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    dailyRate,
                    style: const TextStyle(
                      color: AppColors.mutedForeground,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const _FeatureRow(label: 'Approved instructor dashboard access'),
            const SizedBox(height: AppSpacing.sm),
            const _FeatureRow(label: 'Lesson requests, roster, and scheduling'),
            const SizedBox(height: AppSpacing.sm),
            const _FeatureRow(label: 'Billing checked server-side'),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              label: 'Activate on website',
              onPressed: onPressed,
              isLoading: isLoading,
              height: 52,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle,
          color: AppColors.success,
          size: 18,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.foreground,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _EntitlementBanner extends StatelessWidget {
  const _EntitlementBanner({required this.entitlement});

  final InstructorBillingEntitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final expires = entitlement.accessExpiresAt;
    final message = entitlement.isActive
        ? 'Your pass is active until ${expires?.toLocal().toString().split('.').first}.'
        : 'Your last pass is ${entitlement.status}. Choose a pass to continue.';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: entitlement.isActive
            ? AppColors.success.withValues(alpha: 0.09)
            : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: entitlement.isActive ? AppColors.success : AppColors.warning,
        ),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.foreground,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActivationStatusBanner extends StatelessWidget {
  const _ActivationStatusBanner({required this.isChecking});

  final bool isChecking;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isChecking)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          else
            const Icon(
              Icons.open_in_new,
              color: AppColors.primary,
              size: 19,
            ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              isChecking
                  ? 'Checking your activation status...'
                  : 'Finish activation on DriveTutor.ca, then return here. We will unlock your account automatically.',
              style: const TextStyle(
                color: AppColors.foreground,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BillingErrorState extends StatelessWidget {
  const _BillingErrorState({
    required this.error,
    required this.onRetry,
  });

  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.error,
              size: 40,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Unable to load passes',
              style: TextStyle(
                color: AppColors.foreground,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(label: 'Try again', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}

class _BillingState {
  const _BillingState({
    this.plans = const <InstructorBillingPlan>[],
    this.entitlement,
  });

  final List<InstructorBillingPlan> plans;
  final InstructorBillingEntitlement? entitlement;
}
