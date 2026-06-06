import 'saved_pickup_location.dart';

class LearnerOnboardingDraft {
  const LearnerOnboardingDraft({
    this.role = 'learner',
    this.firstName,
    this.lastName,
    this.phone,
    this.g1LicenceNumber,
    this.g1ExpiryDate,
    this.city,
    this.age,
    this.gender,
    this.classesTakenSoFar,
    this.lastClassDate,
    this.pickupLabel,
    this.pickupAddress,
    this.savedPickupLocations = const [],
    this.weeklyAvailability = const {},
    this.availabilityRecurring = false,
  });

  final String role;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? g1LicenceNumber;
  final DateTime? g1ExpiryDate;
  final String? city;
  final int? age;
  final String? gender;
  final int? classesTakenSoFar;
  final DateTime? lastClassDate;
  final String? pickupLabel;
  final String? pickupAddress;
  final List<SavedPickupLocation> savedPickupLocations;
  final Map<String, List<String>> weeklyAvailability;
  final bool availabilityRecurring;

  LearnerOnboardingDraft copyWith({
    String? role,
    String? firstName,
    String? lastName,
    String? phone,
    String? g1LicenceNumber,
    DateTime? g1ExpiryDate,
    String? city,
    int? age,
    String? gender,
    int? classesTakenSoFar,
    DateTime? lastClassDate,
    String? pickupLabel,
    String? pickupAddress,
    List<SavedPickupLocation>? savedPickupLocations,
    Map<String, List<String>>? weeklyAvailability,
    bool? availabilityRecurring,
  }) {
    return LearnerOnboardingDraft(
      role: role ?? this.role,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      g1LicenceNumber: g1LicenceNumber ?? this.g1LicenceNumber,
      g1ExpiryDate: g1ExpiryDate ?? this.g1ExpiryDate,
      city: city ?? this.city,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      classesTakenSoFar: classesTakenSoFar ?? this.classesTakenSoFar,
      lastClassDate: lastClassDate ?? this.lastClassDate,
      pickupLabel: pickupLabel ?? this.pickupLabel,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      savedPickupLocations: savedPickupLocations ??
          List<SavedPickupLocation>.from(this.savedPickupLocations),
      weeklyAvailability: weeklyAvailability ?? this.weeklyAvailability,
      availabilityRecurring:
          availabilityRecurring ?? this.availabilityRecurring,
    );
  }

  List<Map<String, dynamic>>? get preferredLocationsPayload {
    final locations = savedPickupLocations
        .where((location) => location.address.trim().isNotEmpty)
        .toList();
    if (locations.isNotEmpty) {
      final hasDefault = locations.any((location) => location.isDefault);
      return locations.asMap().entries.map((entry) {
        final location = entry.value;
        return location
            .copyWith(
              isDefault: hasDefault ? location.isDefault : entry.key == 0,
            )
            .toMap();
      }).toList();
    }

    final address = pickupAddress?.trim();
    if (address == null || address.isEmpty) return null;
    final label = pickupLabel?.trim();
    final normalizedLabel = label == null || label.isEmpty ? 'Pickup' : label;
    return [
      {
        'type': normalizedLabel,
        'label': normalizedLabel,
        'address': address,
        'is_default': true,
      },
    ];
  }

  List<Map<String, dynamic>>? get weeklyAvailabilityPayload {
    final payload = weeklyAvailability.entries
        .map((entry) => {'day': entry.key, 'slots': entry.value})
        .where((entry) => (entry['slots'] as List).isNotEmpty)
        .toList();
    return payload.isEmpty ? null : payload;
  }
}
