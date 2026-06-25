class OntarioArea {
  const OntarioArea({
    required this.id,
    required this.name,
    required this.cities,
    required this.neighborIds,
  });

  final String id;
  final String name;
  final List<String> cities;
  final List<String> neighborIds;
}

class OntarioLocations {
  static const String requestRestrictionMessage =
      'Your location is outside instructor service area, please request an other instructor within your zone or area/city';

  static const List<OntarioArea> areas = [
    OntarioArea(
      id: 'kwc',
      name: 'KWC',
      cities: ['Kitchener', 'Waterloo', 'Cambridge'],
      neighborIds: [
        'guelph_orangeville',
        'hamilton_burlington_brantford',
        'london_woodstock',
      ],
    ),
    OntarioArea(
      id: 'guelph_orangeville',
      name: 'Guelph-Orangeville',
      cities: ['Guelph', 'Orangeville'],
      neighborIds: [
        'kwc',
        'hamilton_burlington_brantford',
        'gta_west',
        'newmarket_region',
      ],
    ),
    OntarioArea(
      id: 'hamilton_burlington_brantford',
      name: 'Hamilton-Burlington-Brantford',
      cities: ['Hamilton', 'Burlington', 'Brantford'],
      neighborIds: [
        'kwc',
        'guelph_orangeville',
        'london_woodstock',
        'niagara_region',
        'gta_west',
      ],
    ),
    OntarioArea(
      id: 'niagara_region',
      name: 'Niagara Region',
      cities: ['St. Catharines', 'Niagara Falls'],
      neighborIds: ['hamilton_burlington_brantford'],
    ),
    OntarioArea(
      id: 'london_woodstock',
      name: 'London-Woodstock',
      cities: ['London', 'Woodstock'],
      neighborIds: [
        'kwc',
        'hamilton_burlington_brantford',
        'windsor_chatham_sarnia',
      ],
    ),
    OntarioArea(
      id: 'windsor_chatham_sarnia',
      name: 'Windsor-Chatham-Sarnia',
      cities: ['Windsor', 'Chatham', 'Sarnia'],
      neighborIds: ['london_woodstock'],
    ),
    OntarioArea(
      id: 'barrie_innisfil',
      name: 'Barrie-Innisfil',
      cities: ['Barrie', 'Innisfil'],
      neighborIds: ['newmarket_region'],
    ),
    OntarioArea(
      id: 'gta_west',
      name: 'GTA West',
      cities: ['Mississauga', 'Brampton', 'Oakville'],
      neighborIds: [
        'gta_central',
        'hamilton_burlington_brantford',
        'newmarket_region',
        'guelph_orangeville',
      ],
    ),
    OntarioArea(
      id: 'gta_central',
      name: 'GTA Central',
      cities: ['Toronto', 'Etobicoke', 'Downsview', 'Port Union'],
      neighborIds: ['gta_west', 'gta_east_durham', 'newmarket_region'],
    ),
    OntarioArea(
      id: 'gta_east_durham',
      name: 'GTA East (Durham Region)',
      cities: ['Ajax', 'Oshawa'],
      neighborIds: [
        'gta_central',
        'newmarket_region',
        'eastern_ontario_corridor',
      ],
    ),
    OntarioArea(
      id: 'newmarket_region',
      name: 'Newmarket Region',
      cities: [
        'Newmarket',
        'Aurora',
        'Richmond Hill',
        'Vaughan',
        'Markham',
      ],
      neighborIds: [
        'gta_central',
        'gta_west',
        'gta_east_durham',
        'barrie_innisfil',
        'guelph_orangeville',
      ],
    ),
    OntarioArea(
      id: 'eastern_ontario_corridor',
      name: 'Eastern Ontario Corridor',
      cities: ['Ottawa', 'Kanata', 'Kingston'],
      neighborIds: ['gta_east_durham'],
    ),
  ];

  static List<String> get areaNames =>
      areas.map((area) => area.name).toList(growable: false);

  static List<String> get allCities => areas
      .expand((area) => area.cities)
      .map((city) => city.trim())
      .where((city) => city.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  static List<String> citiesForArea(String? areaName) {
    if (areaName == null) return const [];
    final area = areas.firstWhere(
      (entry) => entry.name == areaName,
      orElse: () => const OntarioArea(
        id: '',
        name: '',
        cities: [],
        neighborIds: [],
      ),
    );
    return area.cities;
  }

  static String? areaForCity(String? city) {
    return clusterForCity(city)?.name;
  }

  static OntarioArea? clusterForCity(String? city) {
    if (city == null) return null;
    final normalized = _normalizeCity(city);
    if (normalized == null) return null;
    for (final area in areas) {
      if (_normalizeCity(area.name) == normalized) {
        return area;
      }
      if (area.cities.map(_normalizeCity).contains(normalized)) {
        return area;
      }
    }
    return null;
  }

  static String? clusterIdForCity(String? city) {
    return clusterForCity(city)?.id;
  }

  static Set<String> requestableClusterIdsForCity(String? learnerCity) {
    final homeCluster = clusterForCity(learnerCity);
    if (homeCluster == null) return const {};
    return {homeCluster.id, ...homeCluster.neighborIds};
  }

  static bool canRequestBetweenCities({
    required String? learnerCity,
    required Iterable<String?> instructorCities,
  }) {
    final allowedClusterIds = requestableClusterIdsForCity(learnerCity);
    if (allowedClusterIds.isEmpty) return false;

    for (final city in instructorCities) {
      final instructorClusterId = clusterIdForCity(city);
      if (instructorClusterId != null &&
          allowedClusterIds.contains(instructorClusterId)) {
        return true;
      }
    }
    return false;
  }

  static bool municipalLicenseRequiredForCity(String? city) {
    final normalized = _normalizeCity(city);
    if (normalized == null) return false;
    return _municipalLicenseRequiredCities.contains(normalized);
  }

  static bool municipalLicenseRequiredForLocations(Iterable<String?> cities) {
    return cities.any(municipalLicenseRequiredForCity);
  }

  static String? _normalizeCity(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.toLowerCase();
  }

  static const Set<String> _municipalLicenseRequiredCities = {
    'toronto',
    'ottawa',
    'mississauga',
    'brampton',
    'vaughan',
    'markham',
    'barrie',
    'guelph',
    'oshawa',
  };
}
