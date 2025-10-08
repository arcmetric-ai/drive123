class AppConstants {
  // App Info
  static const String appName = 'Drive T';
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
    '09:00', '10:00', '11:00', '12:00', 
    '13:00', '14:00', '15:00', '16:00', '17:00'
  ];
  
  static const List<String> lessonDurations = [
    '1 hour',
    '1.5 hours', 
    '2 hours'
  ];
  
  static const List<String> carTypes = [
    'sedan',
    'suv',
    'hatchback',
    'coupe'
  ];
  
  static const List<String> transmissionTypes = [
    'automatic',
    'manual'
  ];
  
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
      'id': '1',
      'name': 'Basic Vehicle Control',
      'description': 'Steering, acceleration, and braking',
      'category': 'basic'
    },
    {
      'id': '2', 
      'name': 'Parking',
      'description': 'Parallel parking and angle parking',
      'category': 'basic'
    },
    {
      'id': '3',
      'name': 'City Driving', 
      'description': 'Traffic lights, signs, and intersections',
      'category': 'intermediate'
    },
    {
      'id': '4',
      'name': 'Highway Driving',
      'description': 'Merging, lane changes, and speed control',
      'category': 'intermediate'
    },
    {
      'id': '5',
      'name': 'Night Driving',
      'description': 'Driving in low light conditions',
      'category': 'advanced'
    },
    {
      'id': '6',
      'name': 'Weather Driving',
      'description': 'Driving in rain, snow, and other conditions',
      'category': 'advanced'
    },
    {
      'id': '7',
      'name': 'Emergency Situations',
      'description': 'Handling unexpected situations',
      'category': 'advanced'
    },
    {
      'id': '8',
      'name': 'Defensive Driving',
      'description': 'Advanced safety techniques',
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
