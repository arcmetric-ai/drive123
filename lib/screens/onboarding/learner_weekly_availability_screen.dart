import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../models/learner_onboarding_draft.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_circle_icon_button.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/availability_day_tabs.dart';
import '../../widgets/availability_slot_card.dart';

class LearnerWeeklyAvailabilityScreen extends StatefulWidget {
  const LearnerWeeklyAvailabilityScreen({
    super.key,
    this.draft = const LearnerOnboardingDraft(),
    this.initialAvailability,
    this.availabilityRecurring = true,
    this.isProfileEdit = false,
  });

  final LearnerOnboardingDraft draft;
  final Map<String, List<String>>? initialAvailability;
  final bool availabilityRecurring;
  final bool isProfileEdit;

  @override
  State<LearnerWeeklyAvailabilityScreen> createState() =>
      _LearnerWeeklyAvailabilityScreenState();
}

class _LearnerWeeklyAvailabilityScreenState
    extends State<LearnerWeeklyAvailabilityScreen> {
  static const _orderedDays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  late Map<String, List<String>> _availability;
  String _selectedDay = 'monday';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final sourceAvailability =
        widget.initialAvailability ?? widget.draft.weeklyAvailability;
    _availability = {
      for (final day in _orderedDays)
        day: List<String>.from(sourceAvailability[day] ?? const []),
    };
  }

  Future<void> _addSlot() async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (start == null || !mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: (start.hour + 2) % 24,
        minute: start.minute,
      ),
    );
    if (end == null || !mounted) return;

    final slot = _encodeSlot(start, end);
    setState(() {
      final current =
          List<String>.from(_availability[_selectedDay] ?? const []);
      current.add(slot);
      current.sort();
      _availability[_selectedDay] = current;
    });
  }

  void _removeSlot(String slot) {
    setState(() {
      final current =
          List<String>.from(_availability[_selectedDay] ?? const []);
      current.remove(slot);
      _availability[_selectedDay] = current;
    });
  }

  void _copyCurrentDayToAllDays() {
    final source = List<String>.from(_availability[_selectedDay] ?? const []);
    setState(() {
      _availability = {
        for (final day in _orderedDays) day: List<String>.from(source),
      };
    });
  }

  Future<void> _handleConfirm() async {
    final hasAnySlots = _availability.values.any((slots) => slots.isNotEmpty);
    if (!hasAnySlots) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one lesson slot to continue.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final draft = widget.draft.copyWith(
      weeklyAvailability: {
        for (final entry in _availability.entries)
          entry.key: List<String>.from(entry.value),
      },
      availabilityRecurring: true,
    );

    setState(() => _isSaving = true);
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('Please sign in again to continue.');
      }

      if (widget.isProfileEdit) {
        await SupabaseService.upsertLearnerProfile(
          userId: userId,
          weeklyAvailability: draft.weeklyAvailabilityPayload,
          availabilityRecurring: widget.availabilityRecurring,
        );
        if (!mounted) return;
        context.pop(true);
      } else {
        await SupabaseService.submitLearnerOnboardingDraft(draft: draft);
        await SupabaseService.updateOnboardingStage(
          userId: userId,
          stage: SupabaseService.onboardingStageQuestionnaireComplete,
        );
        if (!mounted) return;
        context.go(AppRoutes.learningFocus, extra: widget.draft.role);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save availability: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _encodeSlot(TimeOfDay start, TimeOfDay end) {
    String format(TimeOfDay value) {
      final hour = value.hour.toString().padLeft(2, '0');
      final minute = value.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }

    return '${format(start)}-${format(end)}';
  }

  String _titleForDay(String dayKey) {
    final display = dayKey.substring(0, 1).toUpperCase() + dayKey.substring(1);
    return "$display's Slots";
  }

  @override
  Widget build(BuildContext context) {
    final selectedSlots = _availability[_selectedDay] ?? const <String>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AppCircleIconButton(
                          icon: Icons.arrow_back_rounded,
                          size: 56,
                          onPressed: () {
                            if (widget.isProfileEdit) {
                              context.pop();
                              return;
                            }
                            context.go(
                              AppRoutes.learnerPickupAddress,
                              extra: widget.draft,
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Weekly Availability',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.foreground,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Set different lesson times for each day of the week to match your schedule.',
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.45,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 28),
                    AvailabilityDayTabs(
                      selectedDay: _selectedDay,
                      onSelected: (value) => setState(() {
                        _selectedDay = value;
                      }),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A111827),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
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
                                      _titleForDay(_selectedDay),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.foreground,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${selectedSlots.length} slot${selectedSlots.length == 1 ? '' : 's'} available',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: AppColors.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _addSlot,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add Time'),
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFFE4EDFF),
                                  foregroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (selectedSlots.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6F8FC),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: const Text(
                                'No slots added yet. Tap "Add Time" to create your first availability window for this day.',
                                style: TextStyle(
                                  fontSize: 16,
                                  height: 1.45,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            )
                          else
                            ...selectedSlots.map(
                              (slot) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: AvailabilitySlotCard(
                                  slot: slot,
                                  onDelete: () => _removeSlot(slot),
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: selectedSlots.isEmpty
                                ? null
                                : _copyCurrentDayToAllDays,
                            icon: const Icon(Icons.content_copy_rounded),
                            label: Text(
                              'Copy ${_selectedDay.substring(0, 1).toUpperCase()}${_selectedDay.substring(1)} to all days',
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(58),
                              foregroundColor: AppColors.primary,
                              side: BorderSide(
                                color:
                                    AppColors.primary.withValues(alpha: 0.24),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: AppPrimaryButton(
                label: 'Confirm Schedule',
                onPressed: _isSaving ? null : _handleConfirm,
                isLoading: _isSaving,
                height: 64,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
