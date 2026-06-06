import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../models/learner_onboarding_draft.dart';
import '../../models/saved_pickup_location.dart';
import '../../widgets/app_circle_icon_button.dart';
import '../../widgets/app_primary_button.dart';
import '../../widgets/pickup_location_editor_card.dart';

class LearnerPickupAddressScreen extends StatefulWidget {
  const LearnerPickupAddressScreen({super.key, required this.draft});

  final LearnerOnboardingDraft draft;

  @override
  State<LearnerPickupAddressScreen> createState() =>
      _LearnerPickupAddressScreenState();
}

class _LearnerPickupAddressScreenState
    extends State<LearnerPickupAddressScreen> {
  static const _slots = <_PickupSlot>[
    _PickupSlot(type: 'home', label: 'Home', icon: Icons.home_rounded),
    _PickupSlot(type: 'work', label: 'Work', icon: Icons.work_rounded),
    _PickupSlot(
      type: 'other',
      label: 'Gym/Other',
      icon: Icons.fitness_center_rounded,
    ),
  ];

  late final Map<String, _PickupFieldControllers> _controllers;
  late String _defaultType;

  @override
  void initState() {
    super.initState();
    final seededLocations = widget.draft.savedPickupLocations.isNotEmpty
        ? widget.draft.savedPickupLocations
        : _legacySeededLocations(widget.draft);

    _controllers = {
      for (final slot in _slots)
        slot.type: _PickupFieldControllers.fromLocation(
          _findExistingLocation(seededLocations, slot.type),
        ),
    };
    _defaultType = _findDefaultType(seededLocations);
  }

  @override
  void dispose() {
    for (final controllers in _controllers.values) {
      controllers.dispose();
    }
    super.dispose();
  }

  SavedPickupLocation? _findExistingLocation(
    List<SavedPickupLocation> locations,
    String type,
  ) {
    for (final location in locations) {
      if (location.type == type && location.address.trim().isNotEmpty) {
        return location;
      }
    }
    return null;
  }

  List<SavedPickupLocation> _legacySeededLocations(
    LearnerOnboardingDraft draft,
  ) {
    final legacyAddress = draft.pickupAddress?.trim();
    if (legacyAddress == null || legacyAddress.isEmpty) {
      return const [];
    }

    final legacyLabel = draft.pickupLabel?.trim().toLowerCase();
    final type = switch (legacyLabel) {
      'home' => 'home',
      'work' || 'office' => 'work',
      'gym' || 'other' || 'gym/other' => 'other',
      _ => 'home',
    };
    final label = _slots
        .firstWhere((slot) => slot.type == type, orElse: () => _slots.first)
        .label;
    return [
      SavedPickupLocation(
        type: type,
        label: label,
        addressLine1: legacyAddress,
        city: widget.draft.city?.trim(),
        isDefault: true,
      ),
    ];
  }

  String _findDefaultType(List<SavedPickupLocation> locations) {
    for (final location in locations) {
      if (location.isDefault) return location.type;
    }
    for (final location in locations) {
      if (location.address.trim().isNotEmpty) return location.type;
    }
    return 'home';
  }

  String? _normalizePostalCode(String value) {
    final trimmed = value.trim().toUpperCase();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  void _handleContinue() {
    final city = widget.draft.city?.trim();
    final locations = <SavedPickupLocation>[];

    for (final slot in _slots) {
      final controllers = _controllers[slot.type]!;
      final addressLine1 = controllers.addressLine1.text.trim();
      final addressLine2 = controllers.addressLine2.text.trim();
      final postalCode = _normalizePostalCode(controllers.postalCode.text);

      final hasAnyValue = addressLine1.isNotEmpty ||
          addressLine2.isNotEmpty ||
          (postalCode != null && postalCode.isNotEmpty);
      if (!hasAnyValue) continue;

      if (addressLine1.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enter the street address for ${slot.label}.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      locations.add(
        SavedPickupLocation(
          type: slot.type,
          label: slot.label,
          addressLine1: addressLine1,
          addressLine2: addressLine2.isEmpty ? null : addressLine2,
          postalCode: postalCode,
          city: city,
          isDefault: _defaultType == slot.type,
        ),
      );
    }

    if (locations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one saved pickup address to continue.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final normalizedLocations = locations.asMap().entries.map((entry) {
      final location = entry.value;
      return location.copyWith(
        isDefault: locations.any((item) => item.isDefault)
            ? location.isDefault
            : entry.key == 0,
      );
    }).toList();
    final defaultLocation = normalizedLocations.firstWhere(
      (location) => location.isDefault,
      orElse: () => normalizedLocations.first,
    );

    final draft = widget.draft.copyWith(
      pickupLabel: defaultLocation.label,
      pickupAddress: defaultLocation.address,
      savedPickupLocations: normalizedLocations,
    );

    context.go(AppRoutes.learnerWeeklyAvailability, extra: draft);
  }

  @override
  Widget build(BuildContext context) {
    final city = widget.draft.city?.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppCircleIconButton(
                    icon: Icons.arrow_back_rounded,
                    size: 56,
                    onPressed: () => context.go(
                      AppRoutes.learnerQuestionnaire,
                      extra: widget.draft,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pickup Addresses',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: AppColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          city == null || city.isEmpty
                              ? 'Save up to three pickup spots. Instructors will use these to understand where lessons can start.'
                              : 'Save up to three pickup spots in $city. Choose one default location for lesson requests.',
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.45,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (city != null && city.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F6FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.pin_drop_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Selected city: $city',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              const Text(
                'Enter structured pickup details. We do not use any maps API here, so instructors will review the saved locations directly.',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 24),
              ..._slots.map((slot) {
                final controllers = _controllers[slot.type]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: PickupLocationEditorCard(
                    label: slot.label,
                    icon: slot.icon,
                    addressLine1Controller: controllers.addressLine1,
                    addressLine2Controller: controllers.addressLine2,
                    postalCodeController: controllers.postalCode,
                    isDefault: _defaultType == slot.type,
                    cityLabel: city,
                    onDefaultSelected: () {
                      setState(() {
                        _defaultType = slot.type;
                      });
                    },
                  ),
                );
              }),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'Saved locations are stored as learner pickup preferences. You can leave Work or Gym/Other blank if you only use one address.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              AppPrimaryButton(
                label: 'Continue to Availability',
                onPressed: _handleContinue,
                height: 64,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickupSlot {
  const _PickupSlot({
    required this.type,
    required this.label,
    required this.icon,
  });

  final String type;
  final String label;
  final IconData icon;
}

class _PickupFieldControllers {
  _PickupFieldControllers({
    required this.addressLine1,
    required this.addressLine2,
    required this.postalCode,
  });

  factory _PickupFieldControllers.fromLocation(SavedPickupLocation? location) {
    return _PickupFieldControllers(
      addressLine1: TextEditingController(text: location?.addressLine1 ?? ''),
      addressLine2: TextEditingController(text: location?.addressLine2 ?? ''),
      postalCode: TextEditingController(text: location?.postalCode ?? ''),
    );
  }

  final TextEditingController addressLine1;
  final TextEditingController addressLine2;
  final TextEditingController postalCode;

  void dispose() {
    addressLine1.dispose();
    addressLine2.dispose();
    postalCode.dispose();
  }
}
