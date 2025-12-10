class OntarioArea {
  final String name;
  final List<String> cities;

  const OntarioArea({required this.name, required this.cities});
}

class OntarioLocations {
  static const List<OntarioArea> areas = [
    OntarioArea(
      name: 'KWC',
      cities: ['Kitchener', 'Waterloo', 'Cambridge'],
    ),
    OntarioArea(
      name: 'Guelph-Orangeville',
      cities: ['Guelph', 'Orangeville'],
    ),
    OntarioArea(
      name: 'Hamilton-Burlington-Brantford',
      cities: ['Hamilton', 'Burlington', 'Brantford'],
    ),
    OntarioArea(
      name: 'Niagara Region',
      cities: ['St. Catharines', 'Niagara Falls'],
    ),
    OntarioArea(
      name: 'London-Woodstock',
      cities: ['London', 'Woodstock'],
    ),
    OntarioArea(
      name: 'Windsor-Chatham-Sarnia',
      cities: ['Windsor', 'Chatham', 'Sarnia'],
    ),
    OntarioArea(
      name: 'Barrie-Innisfil',
      cities: ['Barrie', 'Innisfil'],
    ),
    OntarioArea(
      name: 'GTA West',
      cities: ['Mississauga', 'Brampton', 'Oakville'],
    ),
    OntarioArea(
      name: 'GTA Central',
      cities: ['Etobicoke', 'Downsview', 'Port Union'],
    ),
    OntarioArea(
      name: 'GTA East (Durham Region)',
      cities: ['Ajax', 'Oshawa'],
    ),
    OntarioArea(
      name: 'Newmarket Region',
      cities: [
        'Newmarket',
        'Aurora',
        'Richmond Hill',
        'Vaughan',
        'Markham',
      ],
    ),
    OntarioArea(
      name: 'Eastern Ontario Corridor',
      cities: ['Ottawa', 'Kanata', 'Kingston'],
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
      orElse: () => const OntarioArea(name: '', cities: []),
    );
    return area.cities;
  }

  static String? areaForCity(String? city) {
    if (city == null) return null;
    final normalized = city.trim().toLowerCase();
    for (final area in areas) {
      if (area.cities.map((c) => c.toLowerCase()).contains(normalized)) {
        return area.name;
      }
    }
    return null;
  }
}
