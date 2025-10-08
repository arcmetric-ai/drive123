import 'user_model.dart';

class InstructorModel {
  // ['english', 'french', etc.]

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
    return InstructorModel(
      id: json['id'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      bio: json['bio'] as String,
      yearsOfExperience: json['years_of_experience'] as int,
      hourlyRate: (json['hourly_rate'] as num).toDouble(),
      rating: (json['rating'] as num).toDouble(),
      totalLessons: json['total_lessons'] as int,
      carTypes: List<String>.from(json['car_types'] as List),
      transmissionTypes: List<String>.from(json['transmission_types'] as List),
      licenseNumber: json['license_number'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String,
      availableDays: List<String>.from(json['available_days'] as List),
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      languages: List<String>.from(json['languages'] as List),
    );
  }
  final String id;
  final UserModel user;
  final String bio;
  final int yearsOfExperience;
  final double hourlyRate;
  final double rating;
  final int totalLessons;
  final List<String> carTypes; // ['automatic', 'manual']
  final List<String> transmissionTypes; // ['automatic', 'manual']
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
}
