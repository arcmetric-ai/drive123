class AppConstants {
  // App Info
  static const String appName = 'Drive Tutor';
  static const String appVersion = '1.0.0';

  // API Configuration
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // Map Configuration
  static const double defaultLatitude = 43.6532; // Toronto
  static const double defaultLongitude = -79.3832;
  static const double defaultZoom = 12.0;
  static const double searchRadius = 10.0; // km

  // Lesson Configuration
  static const List<String> timeSlots = [
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00'
  ];

  static const List<String> lessonDurations = [
    '1 hour',
    '1.5 hours',
    '2 hours'
  ];

  static const List<String> carTypes = [
    'sedan',
    'hatchback',
    'suv',
    'truck',
    'van',
    'coupe',
    'convertible',
    'electric',
    'other',
  ];

  static const List<String> transmissionTypes = ['automatic', 'manual'];

  static const List<String> weekDays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
  ];

  // Skills Configuration
  static const List<Map<String, dynamic>> drivingSkills = [
    {
      'id': 'three_point_turn',
      'name': '3 point turn',
      'description': 'Controlled turnabout in a confined space',
      'category': 'basic'
    },
    {
      'id': 'uphill_park',
      'name': 'Uphill park',
      'description': 'Parking uphill with correct wheel position',
      'category': 'basic'
    },
    {
      'id': 'downhill_park',
      'name': 'Downhill park',
      'description': 'Parking downhill with correct wheel position',
      'category': 'intermediate'
    },
    {
      'id': 'reverse_park',
      'name': 'Reverse park',
      'description': 'Reversing safely into a parking space',
      'category': 'intermediate'
    },
    {
      'id': 'parallel_parking',
      'name': 'Parallel Parking',
      'description': 'Parallel parking with proper observation',
      'category': 'advanced'
    },
    {
      'id': 'u_turn_left_turn',
      'name': 'U- Turn & Left Turn',
      'description': 'Safe U-turns and left turns at intersections',
      'category': 'advanced'
    },
    {
      'id': 'lane_change',
      'name': 'Lane change',
      'description': 'Mirror, signal, blind spot, and smooth lane changes',
      'category': 'advanced'
    },
    {
      'id': 'emergency_full_stop',
      'name': 'Emergency Full Stop',
      'description': 'Controlled emergency stop with safe recovery',
      'category': 'expert'
    },
  ];

  // Validation
  static const int minPasswordLength = 6;
  static const int maxBioLength = 500;
  static const int maxNotesLength = 1000;

  // UI Configuration
  static const double defaultPadding = 16.0;
  static const double cardRadius = 12.0;
  static const double buttonRadius = 8.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 300);
  static const Duration mediumAnimation = Duration(milliseconds: 600);
  static const Duration longAnimation = Duration(milliseconds: 1000);
}
