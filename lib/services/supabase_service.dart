import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;
import 'dart:io';
import '../models/user_model.dart';
import '../models/instructor_model.dart';
import '../models/lesson_model.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  // Auth Methods
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String? phone,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'role': role,
        'phone': phone,
      },
    );
    final user = response.user;
    if (user != null) {
      try {
        await _client.from('profiles').upsert({
          'id': user.id,
          'email': email,
          'phone': phone,
          'role': role,
          'first_name': firstName,
          'last_name': lastName,
        });

        if (role == 'instructor') {
          await _client.from('instructor_profiles').upsert({
            'profile_id': user.id,
          });
        } else if (role == 'learner') {
          await _client.from('learner_profiles').upsert({
            'profile_id': user.id,
          });
        }
      } catch (e) {
        // ignore, profile trigger will still insert minimal row
        print('Warning: unable to upsert profile after signup: $e');
      }
    }
    return response;
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  static User? get currentUser => _client.auth.currentUser;

  // User Methods
  static Future<UserModel?> getUserProfile(String userId) async {
    try {
      final response =
          await _client.from('profiles').select().eq('id', userId).single();

      return UserModel.fromJson(response);
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  static Future<UserModel?> updateUserProfile(UserModel user) async {
    try {
      final response = await _client
          .from('profiles')
          .update(user.toJson())
          .eq('id', user.id)
          .select()
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      print('Error updating user profile: $e');
      return null;
    }
  }

  static Future<void> updateProfileFields(
      String userId, Map<String, dynamic> data) async {
    await _client.from('profiles').update(data).eq('id', userId);
  }

  static Future<String?> uploadProfileImage({
    required String userId,
    required File file,
  }) async {
    final bytes = await file.readAsBytes();
    final fileExtension = file.path.split('.').last;
    final filePath =
        'profile_images/$userId-${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    await _client.storage.from('avatars').uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final publicUrl = _client.storage.from('avatars').getPublicUrl(filePath);

    if (publicUrl.isNotEmpty) {
      await updateProfileFields(userId, {
        'profile_image_url': publicUrl,
      });
    }

    return publicUrl;
  }

  static Future<Map<String, dynamic>?> getRawProfile(String userId) async {
    try {
      return await _client.from('profiles').select().eq('id', userId).single();
    } catch (e) {
      print('Error fetching raw profile: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getInstructorProfileDetail(
      String userId) async {
    try {
      final profile = await _client
          .from('instructor_profiles')
          .select()
          .eq('profile_id', userId)
          .single();
      return profile;
    } catch (e) {
      print('Error fetching instructor profile: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getLearnerProfileDetail(
      String userId) async {
    try {
      final profile = await _client
          .from('learner_profiles')
          .select()
          .eq('profile_id', userId)
          .single();
      return profile;
    } catch (e) {
      print('Error fetching learner profile: $e');
      return null;
    }
  }

  static Future<void> upsertInstructorProfile({
    required String userId,
    String? licenceNumber,
    DateTime? licenceExpiry,
    String? bio,
    String? serviceArea,
    double? defaultRate,
    String? vehicle,
    List<String>? levelsOffered,
    List<String>? languages,
    List<Map<String, dynamic>>? vehicles,
    List<Map<String, dynamic>>? areasOfOperation,
    int? age,
    String? gender,
    List<String>? offerings,
    Map<String, double>? offeringRates,
    List<Map<String, dynamic>>? preferredLocations,
    String? preferredLocationNotes,
  }) async {
    final data = <String, dynamic>{
      'profile_id': userId,
      'licence_number': licenceNumber,
      'licence_expiry': licenceExpiry?.toIso8601String(),
      'bio': bio,
      'levels_offered': levelsOffered,
      'languages': languages,
      'vehicles': vehicles,
      'areas_of_operation': areasOfOperation,
      'age': age,
      'gender': gender,
      'offerings': offerings,
      'offering_rates': offeringRates,
      'preferred_locations': preferredLocations,
      'preferred_location_notes': preferredLocationNotes,
    };

    if (serviceArea != null) {
      data['service_area'] = serviceArea;
    } else if (areasOfOperation != null && areasOfOperation.isNotEmpty) {
      final primaryArea = areasOfOperation.first;
      data['service_area'] = primaryArea['city'];
    }

    if (defaultRate != null) {
      data['default_rate'] = defaultRate;
    } else if (offeringRates != null && offeringRates.isNotEmpty) {
      data['default_rate'] = offeringRates.values.first;
    }

    if (vehicle != null) {
      data['vehicle'] = vehicle;
    } else if (vehicles != null && vehicles.isNotEmpty) {
      final primaryVehicle = vehicles.first;
      final type = (primaryVehicle['type'] as String?)?.trim();
      final year = (primaryVehicle['year'] as String?)?.trim();
      final make = (primaryVehicle['make'] as String?)?.trim();
      final model = (primaryVehicle['model'] as String?)?.trim();
      final numberPlate = (primaryVehicle['numberPlate'] as String?)?.trim();
      final sections = <String>[];
      if (type != null && type.isNotEmpty) {
        sections.add(type);
      }
      final makeModel = [
        if (year != null && year.isNotEmpty) year,
        if (make != null && make.isNotEmpty) make,
        if (model != null && model.isNotEmpty) model,
      ].join(' ');
      if (makeModel.trim().isNotEmpty) {
        sections.add(makeModel.trim());
      }
      if (numberPlate != null && numberPlate.isNotEmpty) {
        sections.add('Plate: $numberPlate');
      }
      data['vehicle'] = sections.join(' • ');
    }

    await _client.from('instructor_profiles').upsert(data);
  }

  static Future<void> upsertLearnerProfile({
    required String userId,
    String? licenceNumber,
    DateTime? licenceExpiry,
    String? learningFocus,
    DateTime? targetTestDate,
    String? testCentre,
    String? notes,
    List<String>? focusAreas,
    String? city,
    int? age,
    String? gender,
    int? classesTaken,
    DateTime? lastClassDate,
    DateTime? g1TestDate,
    List<Map<String, dynamic>>? preferredLocations,
    String? locationNotes,
  }) async {
    await _client.from('learner_profiles').upsert({
      'profile_id': userId,
      'licence_number': licenceNumber,
      'licence_expiry': licenceExpiry?.toIso8601String(),
      'learning_focus': learningFocus,
      'target_test_date': targetTestDate?.toIso8601String(),
      'test_centre': testCentre,
      'notes': notes,
      'focus_areas': focusAreas,
      'city': city,
      'age': age,
      'gender': gender,
      'classes_taken_total': classesTaken,
      'last_class_date': lastClassDate?.toIso8601String(),
      'g1_test_date': g1TestDate?.toIso8601String(),
      'preferred_locations': preferredLocations,
      'preferred_location_notes': locationNotes,
    });
  }

  static Future<List<Map<String, dynamic>>> getLearnerSkillProgress(
      String userId) async {
    try {
      final response = await _client
          .from('learner_skill_progress')
          .select()
          .eq('profile_id', userId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching learner skill progress: $e');
      return [];
    }
  }

  static Future<void> upsertLearnerSkillProgress({
    required String userId,
    required String skillId,
    required bool isCompleted,
    DateTime? completedAt,
  }) async {
    await _client.from('learner_skill_progress').upsert({
      'profile_id': userId,
      'skill_id': skillId,
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getInstructorAvailability(
      String userId) async {
    final results = await _client
        .from('instructor_availability')
        .select()
        .eq('instructor_id', userId)
        .order('weekday');
    return List<Map<String, dynamic>>.from(results);
  }

  static Future<void> addAvailabilitySlot({
    required String userId,
    required int weekday,
    required String startTime,
    required String endTime,
  }) async {
    await _client.from('instructor_availability').insert({
      'instructor_id': userId,
      'weekday': weekday,
      'start_time': startTime,
      'end_time': endTime,
    });
  }

  static Future<void> deleteAvailabilitySlot(String slotId) async {
    await _client.from('instructor_availability').delete().eq('id', slotId);
  }

  static Future<List<Map<String, dynamic>>> getAvailabilityBlocks(
      String userId) async {
    final results = await _client
        .from('instructor_availability_blocks')
        .select()
        .eq('instructor_id', userId)
        .order('block_date');
    return List<Map<String, dynamic>>.from(results);
  }

  static Future<void> addAvailabilityBlock({
    required String userId,
    required DateTime date,
    String? reason,
  }) async {
    await _client.from('instructor_availability_blocks').insert({
      'instructor_id': userId,
      'block_date': date.toIso8601String(),
      'reason': reason,
    });
  }

  static Future<void> removeAvailabilityBlock(String blockId) async {
    await _client
        .from('instructor_availability_blocks')
        .delete()
        .eq('id', blockId);
  }

  static Future<List<Map<String, dynamic>>> getLessonRequestsForInstructor(
      String userId) async {
    final results = await _client
        .from('lesson_requests')
        .select(
            '*, learner:profiles!lesson_requests_learner_id_fkey(id, first_name, last_name, email)')
        .eq('instructor_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(results);
  }

  static Future<List<Map<String, dynamic>>> getLessonRequestsForLearner(
      String userId) async {
    final results = await _client
        .from('lesson_requests')
        .select(
            '*, instructor:instructor_profiles!lesson_requests_instructor_id_fkey(profile_id), instructor_profile:instructor_profiles!lesson_requests_instructor_id_fkey(bio, service_area)')
        .eq('learner_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(results);
  }

  static Future<void> respondToLessonRequest({
    required String requestId,
    required String status,
  }) async {
    await _client
        .from('lesson_requests')
        .update({'status': status}).eq('id', requestId);
  }

  static Future<void> createLessonFromRequest({
    required String requestId,
    required DateTime scheduledAt,
    required int durationMinutes,
  }) async {
    final request = await _client
        .from('lesson_requests')
        .select()
        .eq('id', requestId)
        .maybeSingle();
    if (request == null) return;

    await _client.from('lessons').insert({
      'learner_id': request['learner_id'],
      'instructor_id': request['instructor_id'],
      'scheduled_at': scheduledAt.toIso8601String(),
      'duration_minutes': durationMinutes,
      'focus': request['focus'],
      'status': 'scheduled',
    });
  }

  static Future<List<Map<String, dynamic>>> getUpcomingLessonsForInstructor(
    String userId,
  ) async {
    final now = DateTime.now().toUtc();
    final results = await _client
        .from('lessons')
        .select(
            'id, scheduled_at, duration_minutes, focus, pickup_location, status, learner:profiles(id, first_name, last_name, email)')
        .eq('instructor_id', userId)
        .gte('scheduled_at', now.toIso8601String())
        .order('scheduled_at', ascending: true)
        .limit(10);
    return List<Map<String, dynamic>>.from(results);
  }

  // Instructor Methods
  static Future<List<InstructorModel>> getInstructors({
    double? latitude,
    double? longitude,
    double radius = 10.0, // km
    String? carType,
    String? transmissionType,
    double? minRating,
  }) async {
    try {
      var query =
          _client.from('instructor_profiles').select('*, user:profiles(*)');

      if (minRating != null) {
        query = query.gte('rating', minRating);
      }

      if (carType != null) {
        query = query.contains('car_types', [carType]);
      }

      if (transmissionType != null) {
        query = query.contains('transmission_types', [transmissionType]);
      }

      final response = await query;

      List<InstructorModel> instructors =
          response.map((json) => InstructorModel.fromJson(json)).toList();

      // Filter by distance if coordinates provided
      if (latitude != null && longitude != null) {
        instructors = instructors.where((instructor) {
          final distance = _calculateDistance(
            latitude,
            longitude,
            instructor.latitude,
            instructor.longitude,
          );
          return distance <= radius;
        }).toList();
      }

      return instructors;
    } catch (e) {
      print('Error fetching instructors: $e');
      return [];
    }
  }

  static Future<InstructorModel?> getInstructor(String instructorId) async {
    try {
      final response = await _client
          .from('instructor_profiles')
          .select('*, user:profiles(*)')
          .eq('id', instructorId)
          .single();

      return InstructorModel.fromJson(response);
    } catch (e) {
      print('Error fetching instructor: $e');
      return null;
    }
  }

  // Lesson Methods
  static Future<List<LessonModel>> getLessons(String learnerId) async {
    try {
      final response = await _client
          .from('lessons')
          .select('*, instructor:instructor_profiles(*, user:profiles(*))')
          .eq('learner_id', learnerId)
          .order('scheduled_date', ascending: true);

      return response.map((json) => LessonModel.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching lessons: $e');
      return [];
    }
  }

  static Future<LessonModel?> createLesson({
    required String learnerId,
    required String instructorId,
    required DateTime scheduledDate,
    required String startTime,
    required String endTime,
    required double duration,
    required double cost,
    String? notes,
    String? location,
  }) async {
    try {
      final response = await _client
          .from('lessons')
          .insert({
            'learner_id': learnerId,
            'instructor_id': instructorId,
            'scheduled_date': scheduledDate.toIso8601String(),
            'start_time': startTime,
            'end_time': endTime,
            'duration': duration,
            'cost': cost,
            'notes': notes,
            'location': location,
            'status': 'scheduled',
          })
          .select('*, instructor:instructor_profiles(*, user:profiles(*))')
          .single();

      return LessonModel.fromJson(response);
    } catch (e) {
      print('Error creating lesson: $e');
      return null;
    }
  }

  static Future<LessonModel?> updateLessonStatus(
    String lessonId,
    String status,
  ) async {
    try {
      final response = await _client
          .from('lessons')
          .update({'status': status})
          .eq('id', lessonId)
          .select('*, instructor:instructor_profiles(*, user:profiles(*))')
          .single();

      return LessonModel.fromJson(response);
    } catch (e) {
      print('Error updating lesson status: $e');
      return null;
    }
  }

  // Helper Methods
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = (dLat / 2) * (dLat / 2) +
        (dLon / 2) *
            (dLon / 2) *
            (lat1 * 3.14159 / 180) *
            (lat2 * 3.14159 / 180);

    final double c = 2 * math.sqrt(a);
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (3.14159 / 180);
  }
}
