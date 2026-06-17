import 'dart:math' as math;

class DriveTutorRegionCode {
  const DriveTutorRegionCode({
    required this.regionCode,
    required this.commonCode,
  });

  final String regionCode;
  final String commonCode;
}

class DriveTutorNumberGenerator {
  static final Map<String, DriveTutorRegionCode> _knownRegions = {
    'barrie': const DriveTutorRegionCode(
      regionCode: 'B3',
      commonCode: '387',
    ),
    'barrieinnisfil': const DriveTutorRegionCode(
      regionCode: 'B3',
      commonCode: '387',
    ),
    'innisfil': const DriveTutorRegionCode(
      regionCode: 'B3',
      commonCode: '387',
    ),
    'kitchener': const DriveTutorRegionCode(
      regionCode: 'K7',
      commonCode: '527',
    ),
    'waterloo': const DriveTutorRegionCode(
      regionCode: 'K7',
      commonCode: '527',
    ),
    'cambridge': const DriveTutorRegionCode(
      regionCode: 'K7',
      commonCode: '527',
    ),
    'kwc': const DriveTutorRegionCode(
      regionCode: 'K7',
      commonCode: '527',
    ),
    'torontowest': const DriveTutorRegionCode(
      regionCode: 'T4',
      commonCode: '416',
    ),
    'gtawest': const DriveTutorRegionCode(
      regionCode: 'T4',
      commonCode: '416',
    ),
    'mississauga': const DriveTutorRegionCode(
      regionCode: 'T4',
      commonCode: '416',
    ),
    'brampton': const DriveTutorRegionCode(
      regionCode: 'T4',
      commonCode: '416',
    ),
    'oakville': const DriveTutorRegionCode(
      regionCode: 'T4',
      commonCode: '416',
    ),
  };

  static String generate({
    required String? city,
    required String? serviceArea,
    math.Random? random,
  }) {
    final region = resolve(city: city, serviceArea: serviceArea);
    final suffix = (random ?? math.Random.secure())
        .nextInt(1000)
        .toString()
        .padLeft(3, '0');
    return '${region.regionCode}-${region.commonCode}$suffix';
  }

  static DriveTutorRegionCode resolve({
    required String? city,
    required String? serviceArea,
  }) {
    final candidates = [
      city,
      serviceArea,
    ];
    for (final candidate in candidates) {
      final normalized = normalizeAreaKey(candidate);
      if (normalized == null) continue;
      final direct = _knownRegions[normalized];
      if (direct != null) return direct;
    }

    final fallbackKey =
        normalizeAreaKey(city) ?? normalizeAreaKey(serviceArea) ?? 'ontario';
    final firstLetter = fallbackKey[0].toUpperCase();
    final hash = _positiveHash(fallbackKey);
    final regionDigit = hash % 10;
    final commonCode = ((hash ~/ 10) % 1000).toString().padLeft(3, '0');
    return DriveTutorRegionCode(
      regionCode: '$firstLetter$regionDigit',
      commonCode: commonCode,
    );
  }

  static String? normalizeAreaKey(String? value) {
    if (value == null) return null;
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('&', 'and')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized.isEmpty ? null : normalized;
  }

  static String normalizeSearchText(String? value) {
    return (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static int _positiveHash(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash;
  }
}
