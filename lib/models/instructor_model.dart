import 'dart:convert';

import 'user_model.dart';

class InstructorModel {
  InstructorModel({
    required this.id,
    required this.user,
    required this.bio,
    required this.yearsOfExperience,
    required this.hourlyRate,
    required this.rating,
    required this.totalLessons,
    required this.carTypes,
    required this.transmissionTypes,
    required this.levelsOffered,
    required this.offerings,
    required this.offeringRates,
    required this.vehicles,
    required this.preferredPickupSpots,
    required this.areasOfOperation,
    this.pickupPreference,
    this.locationNotes,
    this.serviceArea,
    this.serviceAreaArea,
    this.serviceAreaCity,
    this.age,
    this.gender,
    this.vehiclePhotoUrl,
    this.licenseNumber,
    this.isVerified = false,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.availableDays,
    required this.startTime,
    required this.endTime,
    required this.languages,
  });

  factory InstructorModel.fromJson(Map<String, dynamic> json) {
    final offerings = _extractOfferings(json);
    final levels = _resolveLevels(json, offerings);
    final offeringRates = _extractOfferingRates(json);
    final vehicles = _parseVehicleList(json['vehicles']);
    final pickupSpots = _parsePickupSpots(json['preferred_locations']);
    final areas = _parseAreaList(
        json['areas_of_operation'] ?? json['preferred_locations']);
    final carTypes = _deriveCarTypes(json, vehicles);
    final transmissions = _deriveTransmissionTypes(json, vehicles);
    final hourlyRate = _extractHourlyRate(json, offeringRates);
    final userJson = json['user'] as Map<String, dynamic>;
    final languagesList = (userJson['languages'] as List?)
            ?.whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList() ??
        const <String>[];
    final pickupPreference = _parseBool(json['pickup_preference']);
    final locationNotes = _cleanString(json['preferred_location_notes']);
    final serviceAreaInfo = _parseServiceArea(json, areas, userJson);

    return InstructorModel(
      id: (json['profile_id'] ?? json['id']).toString(),
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      bio: (json['bio'] as String?) ?? 'Instructor bio coming soon.',
      yearsOfExperience: json['years_of_experience'] as int? ?? 0,
      hourlyRate: hourlyRate,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      totalLessons: json['total_lessons'] as int? ?? 0,
      carTypes: carTypes,
      transmissionTypes: transmissions,
      levelsOffered: levels,
      offerings: offerings.isNotEmpty ? offerings : levels,
      offeringRates: offeringRates,
      vehicles: vehicles,
      preferredPickupSpots: pickupSpots,
      areasOfOperation: areas,
      pickupPreference: pickupPreference,
      locationNotes: locationNotes,
      serviceArea: serviceAreaInfo.label,
      serviceAreaArea: serviceAreaInfo.area,
      serviceAreaCity: serviceAreaInfo.city,
      age: _parseAge(userJson['age']),
      gender: (userJson['gender'] as String?)?.trim().isNotEmpty == true
          ? (userJson['gender'] as String).trim()
          : null,
      vehiclePhotoUrl: (json['vehicle_photo_url'] as String?)?.trim(),
      licenseNumber: _cleanString(userJson['licence_number']) ??
          _cleanString(userJson['license_number']),
      isVerified: json['is_verified'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      address: json['address'] as String? ?? 'Service area not provided',
      availableDays:
          List<String>.from((json['available_days'] as List?) ?? const []),
      startTime: json['start_time'] as String? ?? '09:00',
      endTime: json['end_time'] as String? ?? '17:00',
      languages: languagesList,
    );
  }
  final String id;
  final UserModel user;
  final String bio;
  final int yearsOfExperience;
  final double hourlyRate;
  final double rating;
  final int totalLessons;
  final List<String> carTypes; // ['Sedan', 'SUV']
  final List<String> transmissionTypes; // ['automatic', 'manual']
  final List<String> levelsOffered; // ['G2', 'G', 'PR']
  final List<String>
      offerings; // same as levelsOffered but sourced from offerings column
  final Map<String, double> offeringRates;
  final List<InstructorVehicle> vehicles;
  final List<InstructorPickupSpot> preferredPickupSpots;
  final List<InstructorArea> areasOfOperation;
  final bool? pickupPreference;
  final String? locationNotes;
  final String? serviceArea;
  final String? serviceAreaArea;
  final String? serviceAreaCity;
  final int? age;
  final String? gender;
  final String? vehiclePhotoUrl;
  final String? licenseNumber;
  final bool isVerified;
  final double latitude;
  final double longitude;
  final String address;
  final List<String> availableDays; // ['monday', 'tuesday', etc.]
  final String startTime; // '09:00'
  final String endTime; // '17:00'
  final List<String> languages;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user.toJson(),
      'bio': bio,
      'years_of_experience': yearsOfExperience,
      'hourly_rate': hourlyRate,
      'rating': rating,
      'total_lessons': totalLessons,
      'car_types': carTypes,
      'transmission_types': transmissionTypes,
      'levels_offered': levelsOffered,
      'offerings': offerings,
      'offering_rates': offeringRates,
      'vehicles': vehicles.map((vehicle) => vehicle.toJson()).toList(),
      'preferred_locations':
          preferredPickupSpots.map((spot) => spot.toJson()).toList(),
      'areas_of_operation':
          areasOfOperation.map((area) => area.toJson()).toList(),
      'pickup_preference': pickupPreference,
      'preferred_location_notes': locationNotes,
      'age': age,
      'gender': gender,
      'vehicle_photo_url': vehiclePhotoUrl,
      'license_number': licenseNumber,
      'is_verified': isVerified,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'available_days': availableDays,
      'start_time': startTime,
      'end_time': endTime,
      'languages': languages,
    };
  }

  static List<String> _extractOfferings(Map<String, dynamic> json) {
    final rawOfferings = json['offerings'];
    if (rawOfferings is List) {
      return rawOfferings
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
    }
    if (rawOfferings is String) {
      final trimmed = rawOfferings.trim();
      if (trimmed.isEmpty) {
        return const [];
      }
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .whereType<String>()
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();
        }
      } catch (_) {
        // fall through to manual parsing
      }

      final normalised = trimmed
          .replaceAll(RegExp(r'^\{|\}$'), '')
          .replaceAll('[', '')
          .replaceAll(']', '');
      final parts = normalised
          .split(',')
          .map((value) => value.replaceAll('"', '').replaceAll("'", '').trim())
          .where((value) => value.isNotEmpty)
          .toList();
      if (parts.isNotEmpty) {
        return parts;
      }
    }
    return const [];
  }

  static Map<String, double> _extractOfferingRates(Map<String, dynamic> json) {
    final result = <String, double>{};
    final raw = json['offering_rates'];
    if (raw is Map) {
      raw.forEach((key, value) {
        double? parsed;
        if (value is num) {
          parsed = value.toDouble();
        } else if (value is String) {
          parsed = double.tryParse(value);
        }
        if (parsed != null) {
          result[key.toString()] = parsed;
        }
      });
    }
    return result;
  }

  static double _extractHourlyRate(
    Map<String, dynamic> json,
    Map<String, double> offeringRates,
  ) {
    final direct = json['hourly_rate'];
    if (direct is num && direct > 0) {
      return direct.toDouble();
    }
    if (direct is String) {
      final parsed = double.tryParse(direct);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    final defaultRate = json['default_rate'];
    if (defaultRate is num && defaultRate > 0) {
      return defaultRate.toDouble();
    }
    if (defaultRate is String) {
      final parsed = double.tryParse(defaultRate);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }

    if (offeringRates.isNotEmpty) {
      final iterator = offeringRates.values.iterator;
      iterator.moveNext();
      var minRate = iterator.current;
      while (iterator.moveNext()) {
        if (iterator.current < minRate) {
          minRate = iterator.current;
        }
      }
      return minRate;
    }

    return 0;
  }

  static List<InstructorVehicle> _parseVehicleList(dynamic raw) {
    final vehicles = <InstructorVehicle>[];
    dynamic source = raw;
    if (source is String && source.trim().isNotEmpty) {
      final trimmed = source.trim();
      try {
        source = jsonDecode(trimmed);
      } catch (_) {
        // leave as string; we will attempt to parse manually below
      }
    }

    if (source is List) {
      for (final entry in source) {
        if (entry is Map) {
          vehicles.add(
            InstructorVehicle(
              type: (entry['type'] as String?)?.trim(),
              year: (entry['year'] as String?)?.trim(),
              make: (entry['make'] as String?)?.trim(),
              model: (entry['model'] as String?)?.trim(),
              numberPlate: (entry['numberPlate'] as String?)?.trim(),
              transmission: (entry['transmission'] as String?)?.trim(),
              photoUrl: (entry['photoUrl'] as String?)?.trim() ??
                  (entry['photo_url'] as String?)?.trim(),
            ),
          );
        } else if (entry is String) {
          final parts = entry.split('-').map((part) => part.trim()).toList();
          vehicles.add(
            InstructorVehicle(
              type: parts.isNotEmpty ? parts.first : null,
            ),
          );
        }
      }
    }
    return vehicles;
  }

  static List<InstructorArea> _parseAreaList(dynamic raw) {
    final areas = <InstructorArea>[];
    dynamic source = raw;
    if (source is String && source.trim().isNotEmpty) {
      final trimmed = source.trim();
      try {
        source = jsonDecode(trimmed);
      } catch (_) {
        // ignore parse errors, treat as plain string below
      }
    }

    if (source is List) {
      for (final entry in source) {
        if (entry is Map) {
          final areaName = (entry['area'] as String?)?.trim();
          final city = (entry['city'] as String?)?.trim();
          final radiusRaw = entry['radiusKm'];
          double? radius;
          if (radiusRaw is num) {
            radius = radiusRaw.toDouble();
          } else if (radiusRaw is String) {
            radius = double.tryParse(radiusRaw);
          }
          areas.add(
            InstructorArea(
              areaName: areaName,
              city: city,
              radiusKm: radius,
            ),
          );
        } else if (entry is String && entry.trim().isNotEmpty) {
          areas.add(
            InstructorArea(
              areaName: entry.trim(),
            ),
          );
        }
      }
    }
    return areas;
  }

  static _ServiceAreaInfo _parseServiceArea(
    Map<String, dynamic> json,
    List<InstructorArea> areasOfOperation,
    Map<String, dynamic>? profile,
  ) {
    String? city = _cleanString(profile?['city']);
    String? area = areasOfOperation.isNotEmpty
        ? _cleanString(areasOfOperation.first.areaName)
        : null;
    city ??= areasOfOperation.isNotEmpty
        ? _cleanString(areasOfOperation.first.city)
        : null;
    final label = city ?? area;
    return _ServiceAreaInfo(
      area: area,
      city: city,
      label: label,
    );
  }

  static String? _composeServiceAreaLabel(String? area, String? city) {
    final parts = <String>[];
    final areaValue = _cleanString(area);
    final cityValue = _cleanString(city);
    if (areaValue != null && areaValue.isNotEmpty) {
      parts.add(areaValue);
    }
    if (cityValue != null && cityValue.isNotEmpty) {
      parts.add(cityValue);
    }
    if (parts.isEmpty) return null;
    return parts.join(' - ');
  }

  static String? _cleanString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num) {
      return value.toString();
    }
    if (value is InstructorArea) {
      return value.areaName?.trim().isNotEmpty == true
          ? value.areaName!.trim()
          : null;
    }
    return null;
  }

  static List<InstructorPickupSpot> _parsePickupSpots(dynamic raw) {
    final spots = <InstructorPickupSpot>[];
    dynamic source = raw;
    if (source is String && source.trim().isNotEmpty) {
      final trimmed = source.trim();
      try {
        source = jsonDecode(trimmed);
      } catch (_) {
        // ignore parse error, fall back to treating as plain string
      }
    }

    if (source is List) {
      for (final entry in source) {
        if (entry is Map) {
          spots.add(
            InstructorPickupSpot(
              label: (entry['label'] as String?)?.trim(),
              address: (entry['address'] as String?)?.trim(),
            ),
          );
        } else if (entry is String && entry.trim().isNotEmpty) {
          spots.add(
            InstructorPickupSpot(
              label: entry.trim(),
            ),
          );
        }
      }
    }
    return spots;
  }

  static int? _parseAge(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static List<String> _deriveCarTypes(
    Map<String, dynamic> json,
    List<InstructorVehicle> vehicles,
  ) {
    final rawList = json['car_types'];
    final cleaned = <String>[];
    if (rawList is List) {
      cleaned.addAll(rawList
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty));
    }
    if (cleaned.isNotEmpty) {
      return cleaned;
    }

    for (final vehicle in vehicles) {
      final type = vehicle.type;
      if (type != null && type.isNotEmpty) {
        final formatted =
            type[0].toUpperCase() + type.substring(1).toLowerCase();
        if (!cleaned.contains(formatted)) {
          cleaned.add(formatted);
        }
      }
    }
    return cleaned;
  }

  static List<String> _deriveTransmissionTypes(
    Map<String, dynamic> json,
    List<InstructorVehicle> vehicles,
  ) {
    final rawList = json['transmission_types'];
    final cleaned = <String>[];
    if (rawList is List) {
      cleaned.addAll(rawList
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty));
    }
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
    for (final vehicle in vehicles) {
      final transmission = vehicle.transmission;
      if (transmission != null && transmission.isNotEmpty) {
        final lower = transmission.toLowerCase();
        final formatted = lower[0].toUpperCase() + lower.substring(1);
        if (!cleaned.contains(formatted)) {
          cleaned.add(formatted);
        }
      }
    }
    return cleaned;
  }

  static bool? _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      if (value == 1) return true;
      if (value == 0) return false;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return null;
      if (normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'y') {
        return true;
      }
      if (normalized == 'false' ||
          normalized == '0' ||
          normalized == 'no' ||
          normalized == 'n') {
        return false;
      }
    }
    return null;
  }

  static List<String> _resolveLevels(
    Map<String, dynamic> json,
    List<String> fallbackOfferings,
  ) {
    final rawLevels = json['levels_offered'];
    if (rawLevels is List) {
      final levels = List<String>.from(rawLevels.whereType<String>())
          .where((e) => e.trim().isNotEmpty)
          .toList();
      if (levels.isNotEmpty) {
        return levels;
      }
    }
    return fallbackOfferings;
  }
}

class _ServiceAreaInfo {
  const _ServiceAreaInfo({
    this.area,
    this.city,
    this.label,
  });

  final String? area;
  final String? city;
  final String? label;
}

class InstructorVehicle {
  InstructorVehicle({
    this.type,
    this.year,
    this.make,
    this.model,
    this.numberPlate,
    this.transmission,
    this.photoUrl,
  });

  final String? type;
  final String? year;
  final String? make;
  final String? model;
  final String? numberPlate;
  final String? transmission;
  final String? photoUrl;

  String summary({bool includePlate = false}) {
    final parts = <String>[];
    if (type != null && type!.trim().isNotEmpty) {
      parts.add(type!.trim());
    }
    final makeModel = [
      if (year != null && year!.trim().isNotEmpty) year!.trim(),
      if (make != null && make!.trim().isNotEmpty) make!.trim(),
      if (model != null && model!.trim().isNotEmpty) model!.trim(),
    ].where((value) => value.isNotEmpty).join(' ');
    if (makeModel.isNotEmpty) {
      parts.add(makeModel);
    }
    if (includePlate && numberPlate != null && numberPlate!.trim().isNotEmpty) {
      parts.add('Plate: ${numberPlate!.trim()}');
    }
    return parts.isEmpty ? 'Vehicle details not provided' : parts.join(' �- ');
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'year': year,
        'make': make,
        'model': model,
        'numberPlate': numberPlate,
        'transmission': transmission,
        if (photoUrl != null) 'photoUrl': photoUrl,
      };
}

class InstructorPickupSpot {
  InstructorPickupSpot({
    this.label,
    this.address,
  });

  final String? label;
  final String? address;

  Map<String, dynamic> toJson() => {
        'label': label,
        'address': address,
      };
}

class InstructorArea {
  const InstructorArea({
    this.areaName,
    this.city,
    this.radiusKm,
  });

  final String? areaName;
  final String? city;
  final double? radiusKm;

  Map<String, dynamic> toJson() => {
        'area': areaName,
        'city': city,
        'radiusKm': radiusKm,
      };
}
