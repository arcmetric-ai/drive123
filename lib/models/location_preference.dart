import 'package:shared_preferences/shared_preferences.dart';

class PreferredLocation {
  PreferredLocation({
    required this.type,
    required this.label,
    required this.address,
  });

  final String? type;
  final String? label;
  final String? address;

  factory PreferredLocation.fromMap(Map<dynamic, dynamic> map) {
    return PreferredLocation(
      type: (map['type'] as String?)?.trim(),
      label: (map['label'] as String?)?.trim(),
      address: (map['address'] as String?)?.trim(),
    );
  }

  String get title {
    if (label != null && label!.isNotEmpty) {
      return label!;
    }
    if (type != null && type!.isNotEmpty) {
      return type!.substring(0, 1).toUpperCase() + type!.substring(1);
    }
    return 'Location';
  }

  String get displayText {
    final trimmedAddress = address ?? '';
    if (trimmedAddress.isEmpty) {
      return title;
    }
    return '$title - $trimmedAddress';
  }

  String get storageKey {
    final keyParts = <String>[];
    if (title.isNotEmpty) {
      keyParts.add(title.toLowerCase());
    }
    if ((address ?? '').isNotEmpty) {
      keyParts.add(address!.toLowerCase());
    }
    return keyParts.join('|');
  }
}

class LocationSelectionResult {
  LocationSelectionResult.saved(this.location) : manualAddress = null;

  LocationSelectionResult.manual(String address)
      : manualAddress = address.trim(),
        location = null;

  final PreferredLocation? location;
  final String? manualAddress;

  bool get isManual => location == null;

  String get displayText => isManual ? manualAddress! : location!.displayText;

  String? get storageKey => location?.storageKey;
}

class StoredLocationPreference {
  const StoredLocationPreference({this.key, this.display});

  final String? key;
  final String? display;

  bool get hasValue =>
      (key != null && key!.isNotEmpty) ||
      (display != null && display!.isNotEmpty);
}

class LocationPreferenceStorage {
  static const _keyPreferenceKey = 'drive_t_default_pickup_key';
  static const _displayPreferenceKey = 'drive_t_default_pickup_display';

  static Future<void> save(PreferredLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPreferenceKey, location.storageKey);
    await prefs.setString(_displayPreferenceKey, location.displayText);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPreferenceKey);
    await prefs.remove(_displayPreferenceKey);
  }

  static Future<StoredLocationPreference> load() async {
    final prefs = await SharedPreferences.getInstance();
    return StoredLocationPreference(
      key: prefs.getString(_keyPreferenceKey),
      display: prefs.getString(_displayPreferenceKey),
    );
  }
}

class LocationSetupArgs {
  const LocationSetupArgs({
    required this.savedLocations,
    this.initialSelectionKey,
    this.initialManualAddress,
  });

  final List<PreferredLocation> savedLocations;
  final String? initialSelectionKey;
  final String? initialManualAddress;
}
