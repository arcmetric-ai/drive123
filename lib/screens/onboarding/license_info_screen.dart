import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../services/supabase_service.dart';

class LicenseInfoScreen extends StatefulWidget {
  final String role;
  final String? initialLicenceNumber;
  final DateTime? initialLicenceExpiry;
  final Map<String, dynamic>? questionnaireData;

  const LicenseInfoScreen({
    super.key,
    required this.role,
    this.initialLicenceNumber,
    this.initialLicenceExpiry,
    this.questionnaireData,
  });

  @override
  State<LicenseInfoScreen> createState() => _LicenseInfoScreenState();
}

class _LicenseInfoScreenState extends State<LicenseInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _segment1Controller = TextEditingController();
  final _segment2Controller = TextEditingController();
  final _segment3Controller = TextEditingController();
  final _expiryController = TextEditingController();
  DateTime? _selectedExpiryDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLicenceNumber?.isNotEmpty ?? false) {
      final pattern =
          RegExp(r'^A(\d{4})\s+(\d{5})\s+(\d{5})$', caseSensitive: false);
      final match =
          pattern.firstMatch(widget.initialLicenceNumber!.trim().toUpperCase());
      if (match != null) {
        _segment1Controller.text = match.group(1)!;
        _segment2Controller.text = match.group(2)!;
        _segment3Controller.text = match.group(3)!;
      }
    }
    if (widget.initialLicenceExpiry != null) {
      _selectedExpiryDate = widget.initialLicenceExpiry;
      _expiryController.text =
          DateFormat('MMM d, yyyy').format(widget.initialLicenceExpiry!);
    }
  }

  @override
  void dispose() {
    _segment1Controller.dispose();
    _segment2Controller.dispose();
    _segment3Controller.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpiryDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );

    if (picked != null) {
      setState(() {
        _selectedExpiryDate = picked;
        _expiryController.text = DateFormat('MMM d, yyyy').format(picked);
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No authenticated user found. Please sign in again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      setState(() => _isSubmitting = false);
      return;
    }

    final part1 = _segment1Controller.text.trim();
    final part2 = _segment2Controller.text.trim();
    final part3 = _segment3Controller.text.trim();
    final normalizedLicenceNumber = 'A$part1 $part2 $part3';
    final expiryDate = _selectedExpiryDate;

    if (expiryDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an expiry date.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      Map<String, dynamic> _asMap(dynamic value) {
        if (value is Map) {
          return Map<String, dynamic>.from(value as Map);
        }
        return <String, dynamic>{};
      }

      List<Map<String, dynamic>>? _asMapList(dynamic value) {
        if (value is List) {
          return value
              .where((item) => item is Map)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        }
        return null;
      }

      int? _asInt(dynamic value) {
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) return int.tryParse(value);
        return null;
      }

      double? _asDouble(dynamic value) {
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value);
        return null;
      }

      String? _cleanString(dynamic value) {
        if (value is String) {
          final trimmed = value.trim();
          return trimmed.isEmpty ? null : trimmed;
        }
        return null;
      }

      DateTime? _asDate(dynamic value) {
        if (value is DateTime) return value;
        if (value is String && value.isNotEmpty) {
          return DateTime.tryParse(value);
        }
        return null;
      }

      Future<List<Map<String, dynamic>>?> _ensureVehiclePhotos(
          List<Map<String, dynamic>>? vehicles) async {
        if (vehicles == null) return null;
        final updated = <Map<String, dynamic>>[];
        for (final vehicle in vehicles) {
          final localPath = _cleanString(vehicle['localImagePath']);
          if (localPath != null && localPath.isNotEmpty) {
            final file = File(localPath);
            if (await file.exists()) {
              final url = await SupabaseService.uploadVehicleGalleryImage(
                userId: userId,
                file: file,
              );
              if (url != null && url.isNotEmpty) {
                vehicle['photoUrl'] = url;
              }
            }
            vehicle.remove('localImagePath');
          }
          updated.add(vehicle);
        }
        return updated;
      }

      final questionnaire = widget.questionnaireData;
      final profileUpdates = <String, dynamic>{
        'licence_number': normalizedLicenceNumber,
        'licence_expiry': expiryDate.toIso8601String(),
      };

      if (widget.role == 'instructor') {
        final profileSection =
            questionnaire != null ? _asMap(questionnaire['profile']) : {};
        final instructorSection = questionnaire != null
            ? _asMap(questionnaire['instructorProfile'])
            : {};

        final profileFirstName = _cleanString(profileSection['first_name']);
        final profileLastName = _cleanString(profileSection['last_name']);
        final profilePhone = _cleanString(profileSection['phone']);
        final profileCity = _cleanString(profileSection['city']);
        final profileAge = _asInt(profileSection['age']);
        final profileGender = _cleanString(profileSection['gender']);
        if (profileFirstName != null) {
          profileUpdates['first_name'] = profileFirstName;
        }
        if (profileLastName != null) {
          profileUpdates['last_name'] = profileLastName;
        }
        if (profilePhone != null) {
          profileUpdates['phone'] = profilePhone;
        }
        if (profileCity != null) {
          profileUpdates['city'] = profileCity;
        }
        if (profileAge != null) {
          profileUpdates['age'] = profileAge;
        }
        if (profileGender != null) {
          profileUpdates['gender'] = profileGender;
        }

        final vehicles = await _ensureVehiclePhotos(
            _asMapList(instructorSection['vehicles']));
        final preferredLocations =
            _asMapList(instructorSection['preferred_locations']);
        final offerings = (instructorSection['offerings'] is List)
            ? (instructorSection['offerings'] as List)
                .whereType<String>()
                .toList()
            : null;
        Map<String, double>? offeringRates;
        final rawOfferingRates = instructorSection['offering_rates'];
        if (rawOfferingRates is Map) {
          final parsedRates = <String, double>{};
          rawOfferingRates.forEach((key, value) {
            final parsed = _asDouble(value);
            if (parsed != null) {
              parsedRates[key.toString()] = parsed;
            }
          });
          if (parsedRates.isNotEmpty) {
            offeringRates = parsedRates;
          }
        }
        final defaultRate = _asDouble(instructorSection['default_rate']) ??
            (offeringRates?.values.first);
        final preferredLocationNotes =
            _cleanString(instructorSection['preferred_location_notes']);
        final bio = _cleanString(instructorSection['bio']);
        final yearsOfExperience =
            _asInt(instructorSection['years_of_experience']);
        final vehiclePhotoUrl =
            _cleanString(instructorSection['vehicle_photo_url']);
        bool? pickupPreference;
        final rawPickup = instructorSection['pickup_preference'];
        if (rawPickup is bool) {
          pickupPreference = rawPickup;
        } else if (rawPickup is String) {
          pickupPreference = rawPickup.toLowerCase() == 'true';
        }

        await SupabaseService.updateProfileFields(userId, profileUpdates);
        await SupabaseService.upsertInstructorProfile(
          userId: userId,
          bio: bio,
          defaultRate: defaultRate,
          vehicles: vehicles,
          offerings: offerings,
          offeringRates: offeringRates,
          preferredLocations: pickupPreference == true ? null : preferredLocations,
          clearPreferredLocations: pickupPreference == true,
          preferredLocationNotes: preferredLocationNotes,
          yearsOfExperience: yearsOfExperience,
          vehiclePhotoUrl: vehiclePhotoUrl,
          pickupPreference: pickupPreference,
        );
      } else {
        final profileSection =
            questionnaire != null ? _asMap(questionnaire['profile']) : {};
        final learnerSection = questionnaire != null
            ? _asMap(questionnaire['learnerProfile'])
            : {};

        final profileFirstName = _cleanString(profileSection['first_name']);
        final profileLastName = _cleanString(profileSection['last_name']);
        final profilePhone = _cleanString(profileSection['phone']);
        final profileCity = _cleanString(profileSection['city']);
        final profileAge = _asInt(profileSection['age']);
        final profileGender = _cleanString(profileSection['gender']);

        if (profileFirstName != null) {
          profileUpdates['first_name'] = profileFirstName;
        }
        if (profileLastName != null) {
          profileUpdates['last_name'] = profileLastName;
        }
        if (profilePhone != null) {
          profileUpdates['phone'] = profilePhone;
        }
        if (profileCity != null) {
          profileUpdates['city'] = profileCity;
        }
        if (profileAge != null) {
          profileUpdates['age'] = profileAge;
        }
        if (profileGender != null) {
          profileUpdates['gender'] = profileGender;
        }

        final preferredLocations =
            _asMapList(learnerSection['preferred_locations']);
        final preferredLocationNotes =
            _cleanString(learnerSection['preferred_location_notes']);
        final weeklyAvailability =
            _asMapList(learnerSection['weekly_availability']);
        bool? availabilityRecurring;
        final rawAvailability = learnerSection['availability_recurring'];
        if (rawAvailability is bool) {
          availabilityRecurring = rawAvailability;
        } else if (rawAvailability is String) {
          availabilityRecurring = rawAvailability.toLowerCase() == 'true';
        }
        final classesTaken = _asInt(learnerSection['classes_taken_sofar']);
        final lastClassDate = _asDate(learnerSection['last_class_date']);
        final targetTestDate = _asDate(learnerSection['target_test_date']);
        final notes = _cleanString(learnerSection['notes']);
        final targetTestCentre =
            _cleanString(learnerSection['target_test_centre']);

        await SupabaseService.updateProfileFields(userId, profileUpdates);
        await SupabaseService.upsertLearnerProfile(
          userId: userId,
          learningFocus: _cleanString(learnerSection['learning_focus']),
          targetTestDate: targetTestDate,
          targetTestCentre: targetTestCentre,
          notes: notes,
          classesTakenSoFar: classesTaken,
          lastClassDate: lastClassDate,
          preferredLocations: preferredLocations,
          preferredLocationNotes: preferredLocationNotes,
          weeklyAvailability: weeklyAvailability,
          availabilityRecurring: availabilityRecurring,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to save licence details: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      setState(() => _isSubmitting = false);
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.role == 'learner'
              ? 'Learner details saved! Let’s tailor your training.'
              : 'Instructor credentials saved. Welcome to Drive Tutor!',
        ),
        backgroundColor: AppColors.success,
      ),
    );

    setState(() => _isSubmitting = false);

    await SupabaseService.updateOnboardingStage(
      userId: userId,
      stage: SupabaseService.onboardingStageQuestionnaireComplete,
    );

    if (!mounted) return;

    if (widget.role == 'learner') {
      context.go(AppRoutes.learningFocus, extra: widget.role);
    } else {
      context.go(AppRoutes.instructorCredentialsPortal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLearner = widget.role == 'learner';
    final title = isLearner ? 'Learner Details' : 'Instructor Credentials';
    final subtitle = isLearner
        ? 'Add your G1 licence information to continue'
        : 'Add your instructor licence details to continue';
    final numberLabel =
        isLearner ? 'G1 Licence Number' : 'Instructor Licence Number';
    final buttonColor = isLearner ? AppColors.ocean : AppColors.golden;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: isLearner ? AppColors.ocean : AppColors.golden,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          isLearner ? Icons.assignment : Icons.badge,
                          color: isLearner ? Colors.white : AppColors.ocean,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ocean,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  numberLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _segment1Controller,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        maxLength: 4,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          prefixText: 'A',
                          labelText: isLearner ? 'First block' : 'A + 4 digits',
                          hintText: '1234',
                          fillColor: Colors.grey[50],
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.ocean,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter 4 digits';
                          }
                          if (!RegExp(r'^\d{4}$').hasMatch(value)) {
                            return 'Use 4 digits';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _segment2Controller,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        maxLength: 5,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(5),
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          labelText: 'Second block',
                          hintText: '12345',
                          fillColor: Colors.grey[50],
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.ocean,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter 5 digits';
                          }
                          if (!RegExp(r'^\d{5}$').hasMatch(value)) {
                            return 'Use 5 digits';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _segment3Controller,
                        keyboardType: TextInputType.number,
                        maxLength: 5,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(5),
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          labelText: 'Third block',
                          hintText: '12345',
                          fillColor: Colors.grey[50],
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.ocean,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter 5 digits';
                          }
                          if (!RegExp(r'^\d{5}$').hasMatch(value)) {
                            return 'Use 5 digits';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Format: A1234 12345 12345',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _pickExpiryDate,
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: _expiryController,
                      decoration: InputDecoration(
                        labelText: 'Expiry Date',
                        prefixIcon: const Icon(Icons.calendar_today),
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.ocean,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please select an expiry date';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Continue to Home',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
