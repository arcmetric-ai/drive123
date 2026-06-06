class SavedPickupLocation {
  const SavedPickupLocation({
    required this.type,
    required this.label,
    required this.addressLine1,
    this.addressLine2,
    this.postalCode,
    this.city,
    this.isDefault = false,
  });

  factory SavedPickupLocation.fromMap(Map<dynamic, dynamic> map) {
    final rawType = (map['type'] as String?)?.trim();
    final rawLabel = (map['label'] as String?)?.trim();
    final rawAddress = (map['address'] as String?)?.trim();
    final rawAddressLine1 = (map['address_line_1'] as String?)?.trim();
    final rawAddressLine2 = (map['address_line_2'] as String?)?.trim();
    final rawPostalCode = (map['postal_code'] as String?)?.trim();
    final rawCity = (map['city'] as String?)?.trim();

    return SavedPickupLocation(
      type: rawType == null || rawType.isEmpty ? 'other' : rawType,
      label: rawLabel == null || rawLabel.isEmpty ? 'Location' : rawLabel,
      addressLine1: rawAddressLine1 ?? rawAddress ?? '',
      addressLine2: rawAddressLine2,
      postalCode: rawPostalCode,
      city: rawCity,
      isDefault: map['is_default'] == true,
    );
  }

  final String type;
  final String label;
  final String addressLine1;
  final String? addressLine2;
  final String? postalCode;
  final String? city;
  final bool isDefault;

  String get address {
    final parts = <String>[
      addressLine1.trim(),
      if ((addressLine2 ?? '').trim().isNotEmpty) addressLine2!.trim(),
      if ((city ?? '').trim().isNotEmpty) city!.trim(),
      if ((postalCode ?? '').trim().isNotEmpty) postalCode!.trim(),
    ].where((part) => part.isNotEmpty).toList();
    return parts.join(', ');
  }

  SavedPickupLocation copyWith({
    String? type,
    String? label,
    String? addressLine1,
    String? addressLine2,
    String? postalCode,
    String? city,
    bool? isDefault,
  }) {
    return SavedPickupLocation(
      type: type ?? this.type,
      label: label ?? this.label,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      postalCode: postalCode ?? this.postalCode,
      city: city ?? this.city,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'label': label,
      'address': address,
      'address_line_1': addressLine1,
      'address_line_2': addressLine2,
      'postal_code': postalCode,
      'city': city,
      'is_default': isDefault,
    };
  }
}
