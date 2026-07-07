import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../constants/ontario_locations.dart';
import '../../services/supabase_service.dart';
import '../../utils/ontario_licence.dart';
import '../../utils/ontario_phone_number.dart';

const double _minimumInstructorLessonRate = 40;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;
  String _role = 'learner';

  // Shared licence fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _email = '';
  bool _phoneVerified = false;
  String? _profileImageUrl;
  String? _pendingProfileImagePath;
  final _licenceNumberController = TextEditingController();
  final _licenceExpiryController = TextEditingController();
  DateTime? _licenceExpiryDate;
  bool _licenceNumberLocked = false;

  // Learner fields
  final _g1TestDateController = TextEditingController();
  String? _selectedArea;
  String? _selectedCity;
  final _ageController = TextEditingController();
  final _genderOptions = const [
    'Female',
    'Male',
    'Non-binary',
    'Prefer not to say',
  ];
  final _classesTakenController = TextEditingController();
  final _lastClassDateController = TextEditingController();
  DateTime? _g1TestDate;
  DateTime? _lastClassDate;
  String? _selectedGender;
  String? _learnerTransmission;

  // Instructor fields
  final _instructorAgeController = TextEditingController();
  String? _instructorGender;
  String? _instructorSelectedCity;
  final _yearsExperienceController = TextEditingController();
  bool _pickupPreference = false;

  final List<String> _vehicleTypes = const [
    'Sedan',
    'Hatchback',
    'SUV',
    'Truck',
    'Van',
    'Coupe',
    'Convertible',
    'Electric',
    'Other',
  ];
  String? _selectedVehicleType;
  String? _selectedVehicleTransmission;
  final _vehicleYearController = TextEditingController();
  final _vehicleMakeController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final List<_VehicleEntry> _vehicles = [];
  String? _pendingVehicleImagePath;
  int? _editingVehicleIndex;
  String? _editingVehiclePhotoUrl;
  final ImagePicker _imagePicker = ImagePicker();

  final _bioController = TextEditingController();
  final _languagesController = TextEditingController();
  final _homeLocationController = TextEditingController();
  final _officeLocationController = TextEditingController();
  final _otherLocationLabelController = TextEditingController();
  final _otherLocationAddressController = TextEditingController();
  bool _homeLocationSelected = false;
  bool _officeLocationSelected = false;
  bool _otherLocationSelected = false;

  final List<_OfferingOption> _offeringOptions = const [
    _OfferingOption(code: 'G2', label: 'G2 Road Test'),
    _OfferingOption(code: 'G', label: 'G Road Test'),
    _OfferingOption(code: 'PR', label: 'Refresher Lessons'),
  ];
  final Map<String, bool> _selectedOfferings = {};
  final Map<String, TextEditingController> _rateControllers = {};

  String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    final converted = value.toString().trim();
    return converted.isEmpty ? null : converted;
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _titleCase(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final words = trimmed.split(RegExp(r'\s+'));
    return words
        .map(
          (word) => word.isEmpty
              ? ''
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  List<String> _instructorCityOptions() {
    final options = List<String>.from(OntarioLocations.allCities);
    if (_instructorSelectedCity != null &&
        _instructorSelectedCity!.isNotEmpty &&
        !options.contains(_instructorSelectedCity)) {
      options.insert(0, _instructorSelectedCity!);
    }
    return options;
  }

  @override
  void initState() {
    super.initState();
    for (final option in _offeringOptions) {
      _selectedOfferings[option.code] = false;
      _rateControllers[option.code] = TextEditingController();
    }
    _loadData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _licenceNumberController.dispose();
    _licenceExpiryController.dispose();
    _g1TestDateController.dispose();
    _ageController.dispose();
    _classesTakenController.dispose();
    _lastClassDateController.dispose();
    _instructorAgeController.dispose();
    _yearsExperienceController.dispose();
    _vehicleYearController.dispose();
    _vehicleMakeController.dispose();
    _vehicleModelController.dispose();
    _vehiclePlateController.dispose();
    _bioController.dispose();
    _languagesController.dispose();
    _homeLocationController.dispose();
    _officeLocationController.dispose();
    _otherLocationLabelController.dispose();
    _otherLocationAddressController.dispose();
    for (final controller in _rateControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in again to edit your profile.'),
            backgroundColor: AppColors.error,
          ),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    try {
      final rawProfile = await SupabaseService.getRawProfile(currentUser.id);
      final firstName = _stringOrNull(rawProfile?['first_name']) ??
          _stringOrNull(currentUser.userMetadata?['first_name']) ??
          '';
      final lastName = _stringOrNull(rawProfile?['last_name']) ??
          _stringOrNull(currentUser.userMetadata?['last_name']) ??
          '';
      final phone = _stringOrNull(rawProfile?['phone']) ??
          _stringOrNull(currentUser.userMetadata?['phone']) ??
          '';
      _email = _stringOrNull(rawProfile?['email']) ?? currentUser.email ?? '';
      _firstNameController.text = firstName;
      _lastNameController.text = lastName;
      _phoneController.text = OntarioPhoneNumber.displayLocal(phone);
      _phoneVerified = _stringOrNull(rawProfile?['phone_verified_at']) != null;
      _profileImageUrl = _stringOrNull(rawProfile?['profile_image_url']);

      final role = _stringOrNull(rawProfile?['role']) ??
          currentUser.userMetadata?['role'];
      setState(() {
        _role = (role == 'instructor' || role == 'learner') ? role! : 'learner';
      });

      if (_role == 'learner') {
        await _loadLearnerData(currentUser.id);
      } else {
        await _loadInstructorData(currentUser.id);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to load profile details: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadLearnerData(String userId) async {
    final detail = await SupabaseService.getLearnerProfileDetail(userId);
    if (detail == null) return;

    final profileMap = detail['profile'] is Map
        ? Map<String, dynamic>.from(detail['profile'] as Map)
        : <String, dynamic>{};
    final licenceNumber = _stringOrNull(profileMap['licence_number']);
    final licenceExpiry = _stringOrNull(profileMap['licence_expiry']);
    final targetTestDate = _stringOrNull(detail['target_test_date']);
    final lastClass = _stringOrNull(detail['last_class_date']);

    _licenceNumberController.text =
        licenceNumber == null ? '' : OntarioLicence.format(licenceNumber);
    _licenceNumberLocked =
        _stringOrNull(profileMap['verification_submitted_at']) != null &&
            (licenceNumber?.trim().isNotEmpty ?? false);
    if (licenceExpiry != null) {
      final parsed = DateTime.tryParse(licenceExpiry);
      if (parsed != null) {
        _licenceExpiryDate = parsed;
        _licenceExpiryController.text = DateFormat('yyyy-MM-dd').format(parsed);
      }
    }

    if (targetTestDate != null) {
      final parsed = DateTime.tryParse(targetTestDate);
      if (parsed != null) {
        _g1TestDate = parsed;
        _g1TestDateController.text = DateFormat('yyyy-MM-dd').format(parsed);
      }
    }

    if (lastClass != null) {
      final parsed = DateTime.tryParse(lastClass);
      if (parsed != null) {
        _lastClassDate = parsed;
        _lastClassDateController.text = DateFormat('yyyy-MM-dd').format(parsed);
      }
    }

    _selectedCity = _stringOrNull(profileMap['city']);
    if (_selectedCity != null) {
      _selectedArea = OntarioLocations.areaForCity(_selectedCity);
    }
    final age = profileMap['age'];
    if (age is int) {
      _ageController.text = age.toString();
    } else if (age is String) {
      _ageController.text = age;
    }

    final gender = _stringOrNull(profileMap['gender']);
    if (gender is String && gender.isNotEmpty) {
      _selectedGender = gender;
    } else {
      _selectedGender = null;
    }

    final classesTaken = detail['classes_taken_sofar'];
    _learnerTransmission = _stringOrNull(detail['transmission_preference']);
    if (classesTaken is int) {
      _classesTakenController.text = classesTaken.toString();
    } else if (classesTaken is String) {
      _classesTakenController.text = classesTaken;
    } else {
      _classesTakenController.clear();
    }

    final locations = detail['preferred_locations'];
    _homeLocationSelected = false;
    _officeLocationSelected = false;
    _otherLocationSelected = false;
    _homeLocationController.clear();
    _officeLocationController.clear();
    _otherLocationLabelController.clear();
    _otherLocationAddressController.clear();
    if (locations is List) {
      for (final entry in locations) {
        if (entry is Map) {
          final type = _stringOrNull(entry['type'])?.toLowerCase();
          final label = _stringOrNull(entry['label']);
          final address = _stringOrNull(entry['address']);
          if (type == 'home') {
            _homeLocationSelected = true;
            _homeLocationController.text = address ?? '';
          } else if (type == 'office' || type == 'work') {
            _officeLocationSelected = true;
            _officeLocationController.text = address ?? '';
          } else if (type == 'other') {
            _otherLocationSelected = true;
            _otherLocationLabelController.text = label ?? '';
            _otherLocationAddressController.text = address ?? '';
          } else if (type == 'gym') {
            _otherLocationSelected = true;
            _otherLocationLabelController.text = label ?? 'Gym/Other';
            _otherLocationAddressController.text = address ?? '';
          }
        }
      }
    }
  }

  Future<void> _loadInstructorData(String userId) async {
    final detail = await SupabaseService.getInstructorProfileDetail(userId);
    if (detail == null) return;

    _vehicles.clear();
    _pickupPreference = false;

    final profileMap = detail['profile'] is Map
        ? Map<String, dynamic>.from(detail['profile'] as Map)
        : <String, dynamic>{};
    final licenceNumber = _stringOrNull(profileMap['licence_number']);
    final licenceExpiry = _stringOrNull(profileMap['licence_expiry']);

    _licenceNumberController.text =
        licenceNumber == null ? '' : OntarioLicence.format(licenceNumber);
    _licenceNumberLocked =
        _stringOrNull(profileMap['verification_submitted_at']) != null &&
            (licenceNumber?.trim().isNotEmpty ?? false);
    if (licenceExpiry != null) {
      final parsed = DateTime.tryParse(licenceExpiry);
      if (parsed != null) {
        _licenceExpiryDate = parsed;
        _licenceExpiryController.text = DateFormat('yyyy-MM-dd').format(parsed);
      }
    }

    final age = profileMap['age'];
    if (age is int) {
      _instructorAgeController.text = age.toString();
    } else if (age is String) {
      _instructorAgeController.text = age;
    }

    final genderValue = _stringOrNull(profileMap['gender']);
    _instructorGender =
        genderValue != null && genderValue.isNotEmpty ? genderValue : null;
    final yearsExperienceRaw = detail['years_of_experience'];
    if (yearsExperienceRaw is num) {
      _yearsExperienceController.text = yearsExperienceRaw.toInt().toString();
    } else if (yearsExperienceRaw is String &&
        yearsExperienceRaw.trim().isNotEmpty) {
      _yearsExperienceController.text = yearsExperienceRaw.trim();
    } else {
      _yearsExperienceController.clear();
    }
    final pickupPreferenceRaw = detail['pickup_preference'];
    if (pickupPreferenceRaw is bool) {
      _pickupPreference = pickupPreferenceRaw;
    } else if (pickupPreferenceRaw is String) {
      final lowercase = pickupPreferenceRaw.toLowerCase();
      if (lowercase == 'true' || lowercase == '1') {
        _pickupPreference = true;
      } else if (lowercase == 'false' || lowercase == '0') {
        _pickupPreference = false;
      }
    }

    _instructorSelectedCity = _stringOrNull(profileMap['city']);
    _bioController.text = _stringOrNull(detail['bio']) ?? '';

    final vehicles = detail['vehicles'];
    if (vehicles is List) {
      for (final entry in vehicles) {
        if (entry is Map) {
          final type = _stringOrNull(entry['type']);
          final year = _stringOrNull(entry['year']);
          final make = _stringOrNull(entry['make']);
          final model = _stringOrNull(entry['model']);
          final plate = _stringOrNull(entry['numberPlate']);

          if (type != null &&
              year != null &&
              make != null &&
              model != null &&
              plate != null) {
            final transmission = _stringOrNull(entry['transmission']);
            _vehicles.add(
              _VehicleEntry(
                type: type,
                year: year,
                make: make,
                model: model,
                numberPlate: plate,
                transmission:
                    transmission?.isNotEmpty == true ? transmission : null,
                photoUrl: _stringOrNull(entry['photoUrl']) ??
                    _stringOrNull(entry['photo_url']),
              ),
            );
          }
        }
      }
    }

    final offerings = detail['offerings'];
    if (offerings is List) {
      for (final option in _offeringOptions) {
        _selectedOfferings[option.code] =
            offerings.contains(option.code) ? true : false;
      }
    }

    final rates = detail['offering_rates'];
    if (rates is Map) {
      rates.forEach((key, value) {
        final controller = _rateControllers[key];
        if (controller != null) {
          if (value is num) {
            controller.text = value.toString();
          } else if (value is String) {
            controller.text = value;
          }
        }
      });
    }

    final languages = profileMap['languages'];
    if (languages is List) {
      final formattedLanguages = languages
          .whereType<String>()
          .map(_titleCase)
          .where((value) => value.isNotEmpty)
          .toList();
      _languagesController.text = formattedLanguages.join(', ');
    } else {
      _languagesController.text = '';
    }

    _homeLocationSelected = false;
    _officeLocationSelected = false;
    _otherLocationSelected = false;
    _homeLocationController.clear();
    _officeLocationController.clear();
    _otherLocationLabelController.clear();
    _otherLocationAddressController.clear();
    final locations = detail['preferred_locations'];
    if (locations is List) {
      for (final entry in locations) {
        if (entry is Map) {
          final type = _stringOrNull(entry['type'])?.toLowerCase();
          final label = _stringOrNull(entry['label']);
          final address = _stringOrNull(entry['address']);
          if (type == 'home') {
            _homeLocationSelected = true;
            _homeLocationController.text = address ?? '';
          } else if (type == 'office' || type == 'work') {
            _officeLocationSelected = true;
            _officeLocationController.text = address ?? '';
          } else if (type == 'other') {
            _otherLocationSelected = true;
            _otherLocationLabelController.text = label ?? '';
            _otherLocationAddressController.text = address ?? '';
          } else if (type == 'gym') {
            _otherLocationSelected = true;
            _otherLocationLabelController.text = label ?? 'Gym/Other';
            _otherLocationAddressController.text = address ?? '';
          }
        }
      }
    }
  }

  void _clearInstructorLocationSelections() {
    _homeLocationSelected = false;
    _officeLocationSelected = false;
    _otherLocationSelected = false;
    _homeLocationController.clear();
    _officeLocationController.clear();
    _otherLocationLabelController.clear();
    _otherLocationAddressController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _handleSave,
            child: const Text(
              'Save',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _role == 'learner'
                            ? 'Learner Profile Settings'
                            : 'Instructor Profile Settings',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildPersonalInfoForm(),
                      const SizedBox(height: 24),
                      if (_role == 'learner') _buildLearnerForm(),
                      if (_role == 'instructor') _buildInstructorForm(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildPersonalInfoForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'First Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'First name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Last Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Last name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: ValueKey(_email),
              initialValue: _email,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixText: '+1 ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: _phoneVerified
                  ? const Chip(
                      avatar: Icon(Icons.verified_rounded, size: 18),
                      label: Text('Phone verified'),
                    )
                  : TextButton.icon(
                      onPressed: _verifyPhoneNumber,
                      icon: const Icon(Icons.sms_outlined),
                      label: const Text('Verify phone number'),
                    ),
            ),
            const SizedBox(height: 12),
            _buildProfilePhotoPicker(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePhotoPicker() {
    ImageProvider<Object>? image;
    final pendingPath = _pendingProfileImagePath;
    if (pendingPath != null && pendingPath.isNotEmpty) {
      image = FileImage(File(pendingPath));
    } else if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      image = NetworkImage(_profileImageUrl!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Profile Photo',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            CircleAvatar(
              radius: 42,
              backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
              backgroundImage: image,
              child: image == null
                  ? const Icon(
                      Icons.person_rounded,
                      size: 42,
                      color: AppColors.primaryBlue,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickProfileImage(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Take photo'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _pickProfileImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Choose photo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked != null) {
        setState(() => _pendingProfileImagePath = picked.path);
      }
    } catch (e) {
      if (!mounted) return;
      _showInlineError('Unable to pick profile photo: $e');
    }
  }

  Future<void> _verifyPhoneNumber() async {
    final rawPhone = _phoneController.text.trim();
    final phone = OntarioPhoneNumber.toE164(rawPhone);
    if (rawPhone.isNotEmpty && phone == null) {
      _showInlineError('Enter a valid 10-digit Ontario phone number.');
      return;
    }
    if (phone == null) {
      _showInlineError('Enter a valid 10-digit Ontario phone number.');
      return;
    }
    try {
      await SupabaseService.sendPhoneVerificationCode(phone);
    } catch (error) {
      if (!mounted) return;
      _showInlineError('Unable to send the verification code: $error');
      return;
    }
    if (!mounted) return;

    final controller = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verify phone number'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '6-digit code',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (token == null || token.trim().length != 6) return;

    try {
      await SupabaseService.verifyPhoneChangeCode(phone: phone, token: token);
      if (!mounted) return;
      setState(() => _phoneVerified = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number verified.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showInlineError('That code could not be verified: $error');
    }
  }

  Widget _buildLearnerForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('G1/G2/G Licence Details'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _licenceNumberController,
          enabled: !_licenceNumberLocked,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'G1/G2/G Licence Number',
            helperText: _licenceNumberLocked
                ? 'Licence number is locked after verification submission.'
                : 'Ontario format: A1234 12345 12345',
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Licence number is required';
            }
            if (!OntarioLicence.isValid(value)) {
              return 'Use Ontario format A1234 12345 12345';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _licenceExpiryController,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Licence Expiry',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.calendar_today),
          ),
          onTap: () => _pickDate(
            controller: _licenceExpiryController,
            currentValue: _licenceExpiryDate,
            firstDate: DateTime.now(),
            onSelected: (value) => setState(() {
              _licenceExpiryDate = value;
            }),
          ),
          validator: (value) {
            if ((value ?? '').isEmpty) {
              return 'Select an expiry date';
            }
            final expiry = _licenceExpiryDate;
            if (expiry != null) {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              if (expiry.isBefore(today)) {
                return 'Expiry cannot be in the past';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _g1TestDateController,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'G1 Test Date',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.calendar_today),
          ),
          onTap: () => _pickDate(
            controller: _g1TestDateController,
            currentValue: _g1TestDate,
            firstDate: _today,
            lastDate: DateTime(_today.year + 10),
            onSelected: (value) => setState(() {
              _g1TestDate = value;
            }),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Personal Details'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _learnerTransmission,
          decoration: const InputDecoration(
            labelText: 'Car transmission you are learning',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'automatic', child: Text('Automatic')),
            DropdownMenuItem(value: 'manual', child: Text('Manual')),
          ],
          onChanged: (value) => setState(() => _learnerTransmission = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedArea,
          decoration: const InputDecoration(
            labelText: 'Area',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Select area'),
            ),
            ...OntarioLocations.areaNames.map(
              (area) => DropdownMenuItem(value: area, child: Text(area)),
            ),
          ],
          onChanged: (value) => setState(() {
            _selectedArea = value;
            if (value != null) {
              final cities = OntarioLocations.citiesForArea(value);
              if (cities.isNotEmpty) {
                if (_selectedCity == null || !cities.contains(_selectedCity)) {
                  _selectedCity = cities.first;
                }
              } else {
                _selectedCity = null;
              }
            } else {
              _selectedCity = null;
            }
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedCity,
          decoration: const InputDecoration(
            labelText: 'City',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Select city'),
            ),
            ...((_selectedArea != null
                    ? OntarioLocations.citiesForArea(_selectedArea)
                    : OntarioLocations.allCities))
                .map(
              (city) => DropdownMenuItem(value: city, child: Text(city)),
            ),
          ],
          onChanged: (value) => setState(() => _selectedCity = value),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'City is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _ageController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Age',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Age is required';
            }
            final parsed = int.tryParse(value.trim());
            if (parsed == null || parsed <= 0) {
              return 'Enter a valid age';
            }
            if (parsed < 18) {
              return parsed == 16 || parsed == 17
                  ? 'Ages 16-17 require a guardian account'
                  : 'Learners must be at least 16 years old';
            }
            if (parsed > 100) {
              return 'Enter a valid age';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedGender,
          items: _genderOptions
              .map(
                (gender) =>
                    DropdownMenuItem(value: gender, child: Text(gender)),
              )
              .toList(),
          decoration: const InputDecoration(
            labelText: 'Gender',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _selectedGender = value),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a gender option';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Preferred Lesson Locations'),
        const SizedBox(height: 12),
        CheckboxListTile(
          title: const Text('Home'),
          value: _homeLocationSelected,
          onChanged: (value) {
            setState(() {
              _homeLocationSelected = value ?? false;
              if (!_homeLocationSelected) {
                _homeLocationController.clear();
              }
            });
          },
        ),
        if (_homeLocationSelected)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            child: TextField(
              controller: _homeLocationController,
              decoration: const InputDecoration(
                labelText: 'Home Address',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        CheckboxListTile(
          title: const Text('Work'),
          value: _officeLocationSelected,
          onChanged: (value) {
            setState(() {
              _officeLocationSelected = value ?? false;
              if (!_officeLocationSelected) {
                _officeLocationController.clear();
              }
            });
          },
        ),
        if (_officeLocationSelected)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            child: TextField(
              controller: _officeLocationController,
              decoration: const InputDecoration(
                labelText: 'Work Address',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        CheckboxListTile(
          title: const Text('Gym/Other'),
          value: _otherLocationSelected,
          onChanged: (value) {
            setState(() {
              _otherLocationSelected = value ?? false;
              if (!_otherLocationSelected) {
                _otherLocationLabelController.clear();
                _otherLocationAddressController.clear();
              }
            });
          },
        ),
        if (_otherLocationSelected) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            child: TextField(
              controller: _otherLocationLabelController,
              decoration: const InputDecoration(
                labelText: 'Custom Label',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            child: TextField(
              controller: _otherLocationAddressController,
              decoration: const InputDecoration(
                labelText: 'Gym/Other Address',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _buildSectionTitle('Lesson History'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _classesTakenController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Previous lessons completed (optional)',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return null;
            }
            final parsed = int.tryParse(value.trim());
            if (parsed == null || parsed < 0) {
              return 'Enter a valid number';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _lastClassDateController,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Most recent class date',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.calendar_today),
          ),
          onTap: () => _pickDate(
            controller: _lastClassDateController,
            currentValue: _lastClassDate,
            firstDate: DateTime(1970),
            lastDate: _today,
            preferLatestInitial: true,
            onSelected: (value) => setState(() {
              _lastClassDate = value;
            }),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInstructorForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Ontario G Licence'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _licenceNumberController,
          enabled: !_licenceNumberLocked,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Ontario G Licence Number',
            helperText: _licenceNumberLocked
                ? 'Licence number is locked after verification submission.'
                : 'Ontario format: A1234 12345 12345',
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Licence number is required';
            }
            if (!OntarioLicence.isValid(value)) {
              return 'Use Ontario format A1234 12345 12345';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _licenceExpiryController,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Licence Expiry',
            border: OutlineInputBorder(),
            suffixIcon: Icon(Icons.calendar_today),
          ),
          onTap: () => _pickDate(
            controller: _licenceExpiryController,
            currentValue: _licenceExpiryDate,
            firstDate: DateTime.now(),
            onSelected: (value) => setState(() {
              _licenceExpiryDate = value;
            }),
          ),
          validator: (value) {
            if ((value ?? '').isEmpty) {
              return 'Select an expiry date';
            }
            final expiry = _licenceExpiryDate;
            if (expiry != null) {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              if (expiry.isBefore(today)) {
                return 'Expiry cannot be in the past';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Professional Profile'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _instructorSelectedCity,
          decoration: const InputDecoration(
            labelText: 'City',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Select city'),
            ),
            ..._instructorCityOptions().map(
              (city) => DropdownMenuItem(value: city, child: Text(city)),
            ),
          ],
          onChanged: (value) => setState(() {
            _instructorSelectedCity =
                value != null && value.isNotEmpty ? value : null;
          }),
          validator: (value) {
            if (_role != 'instructor') return null;
            if (value == null || value.trim().isEmpty) {
              return 'City is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _bioController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Bio',
            hintText:
                'Describe your experience so learners know what to expect.',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _languagesController,
          decoration: const InputDecoration(
            labelText: 'Languages (comma separated)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _yearsExperienceController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Years of experience',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return null;
            }
            final parsed = int.tryParse(value.trim());
            if (parsed == null || parsed < 0) {
              return 'Enter a valid number of years';
            }
            final instructorAge =
                int.tryParse(_instructorAgeController.text.trim());
            if (instructorAge != null && parsed > instructorAge) {
              return 'Experience cannot be greater than age';
            }
            if (parsed > 80) {
              return 'Enter a realistic number of years';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Offer learner pickup?'),
          subtitle: const Text('I can pick learners up from their location.'),
          value: _pickupPreference,
          onChanged: (value) {
            setState(() {
              _pickupPreference = value;
              if (value) {
                _clearInstructorLocationSelections();
              }
            });
          },
        ),
        if (!_pickupPreference) ...[
          const SizedBox(height: 12),
          _buildSectionTitle('Preferred Lesson Locations'),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: const Text('Home'),
            value: _homeLocationSelected,
            onChanged: (value) {
              setState(() {
                _homeLocationSelected = value ?? false;
                if (!_homeLocationSelected) {
                  _homeLocationController.clear();
                }
              });
            },
          ),
          if (_homeLocationSelected)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 12),
              child: TextField(
                controller: _homeLocationController,
                decoration: const InputDecoration(
                  labelText: 'Home Address',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          CheckboxListTile(
            title: const Text('Work'),
            value: _officeLocationSelected,
            onChanged: (value) {
              setState(() {
                _officeLocationSelected = value ?? false;
                if (!_officeLocationSelected) {
                  _officeLocationController.clear();
                }
              });
            },
          ),
          if (_officeLocationSelected)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 12),
              child: TextField(
                controller: _officeLocationController,
                decoration: const InputDecoration(
                  labelText: 'Work Address',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          CheckboxListTile(
            title: const Text('Gym/Other'),
            value: _otherLocationSelected,
            onChanged: (value) {
              setState(() {
                _otherLocationSelected = value ?? false;
                if (!_otherLocationSelected) {
                  _otherLocationLabelController.clear();
                  _otherLocationAddressController.clear();
                }
              });
            },
          ),
          if (_otherLocationSelected) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 12),
              child: TextField(
                controller: _otherLocationLabelController,
                decoration: const InputDecoration(
                  labelText: 'Custom Label',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 12),
              child: TextField(
                controller: _otherLocationAddressController,
                decoration: const InputDecoration(
                  labelText: 'Gym/Other Address',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ],
        const SizedBox(height: 24),
        _buildSectionTitle('Vehicles'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedVehicleType,
          items: _vehicleTypes
              .map((type) => DropdownMenuItem(value: type, child: Text(type)))
              .toList(),
          decoration: const InputDecoration(
            labelText: 'Vehicle Type',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _selectedVehicleType = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedVehicleTransmission,
          decoration: const InputDecoration(
            labelText: 'Transmission',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'automatic', child: Text('Automatic')),
            DropdownMenuItem(value: 'manual', child: Text('Manual')),
          ],
          onChanged: (value) =>
              setState(() => _selectedVehicleTransmission = value),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: TextField(
                controller: _vehicleYearController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Year',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _vehicleMakeController,
                decoration: const InputDecoration(
                  labelText: 'Make / Company',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _vehicleModelController,
          decoration: const InputDecoration(
            labelText: 'Model',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _vehiclePlateController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Number Plate',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickPendingVehicleImage,
              icon: const Icon(Icons.photo_camera_back_outlined),
              label: Text(
                _pendingVehicleImagePath == null
                    ? 'Add vehicle photo'
                    : 'Change vehicle photo',
              ),
            ),
            if (_pendingVehicleImagePath != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove selected photo',
                onPressed: () =>
                    setState(() => _pendingVehicleImagePath = null),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
        if (_pendingVehicleImagePath != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(_pendingVehicleImagePath!),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _handleAddVehicle,
            icon: const Icon(Icons.add),
            label: Text(
              _editingVehicleIndex == null ? 'Add vehicle' : 'Update vehicle',
            ),
          ),
        ),
        if (_vehicles.isNotEmpty) ...[
          const SizedBox(height: 12),
          Column(
            children: _vehicles
                .map(
                  (vehicle) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: _buildVehiclePhotoChip(vehicle),
                      title: Text(
                        '${vehicle.type} • ${vehicle.year} ${vehicle.make} ${vehicle.model}',
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Plate: ${vehicle.numberPlate}'),
                          if (vehicle.hasPhoto)
                            Text(
                              'Photo attached',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                      trailing: Wrap(
                        spacing: 2,
                        children: [
                          IconButton(
                            tooltip: 'Edit vehicle',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _beginEditingVehicle(vehicle),
                          ),
                          IconButton(
                            tooltip: 'Remove vehicle',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() {
                              _vehicles.remove(vehicle);
                              _editingVehicleIndex = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 24),
        _buildSectionTitle('Personal Details'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _instructorAgeController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Age',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (_role != 'instructor') return null;
            if (value == null || value.trim().isEmpty) {
              return 'Age is required';
            }
            final parsed = int.tryParse(value.trim());
            if (parsed == null || parsed <= 0) {
              return 'Enter a valid age';
            }
            if (parsed < 21) {
              return 'Instructors must be at least 21 years old';
            }
            if (parsed > 100) {
              return 'Enter a valid age';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _instructorGender,
          items: _genderOptions
              .map(
                (gender) =>
                    DropdownMenuItem(value: gender, child: Text(gender)),
              )
              .toList(),
          decoration: const InputDecoration(
            labelText: 'Gender',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _instructorGender = value),
          validator: (value) {
            if (_role != 'instructor') return null;
            if (value == null || value.isEmpty) {
              return 'Please select a gender option';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Offerings & Rates'),
        const SizedBox(height: 12),
        Column(
          children: _offeringOptions.map((option) {
            final isSelected = _selectedOfferings[option.code] ?? false;
            final controller = _rateControllers[option.code]!;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) => setState(() {
                      _selectedOfferings[option.code] = value ?? false;
                      if (!(value ?? false)) {
                        controller.clear();
                      }
                    }),
                    title: Text(option.label),
                  ),
                  if (isSelected)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Hourly rate (\$)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_role == 'learner') {
      await _saveLearnerProfile();
    } else {
      await _saveInstructorProfile();
    }
  }

  Future<void> _saveLearnerProfile() async {
    if ((_pendingProfileImagePath == null ||
            _pendingProfileImagePath!.trim().isEmpty) &&
        (_profileImageUrl == null || _profileImageUrl!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a profile photo to continue.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_licenceExpiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a licence expiry date.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_pickupPreference &&
        !_homeLocationSelected &&
        !_officeLocationSelected &&
        !_otherLocationSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one preferred lesson location.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    final age = int.tryParse(_ageController.text.trim());
    final classesTakenText = _classesTakenController.text.trim();
    final classesTaken =
        classesTakenText.isEmpty ? 0 : int.tryParse(classesTakenText);
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final rawPhone = _phoneController.text.trim();
    final phone = OntarioPhoneNumber.toE164(rawPhone);
    if (rawPhone.isNotEmpty && phone == null) {
      _showInlineError('Enter a valid 10-digit Ontario phone number.');
      return;
    }
    if (age != null && age < 18) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            age == 16 || age == 17
                ? 'You are $age years old and require a guardian account instead of a learner account.'
                : 'Learners must be at least 16 years old.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_lastClassDate != null && _lastClassDate!.isAfter(_today)) {
      _showInlineError('Most recent class date cannot be in the future.');
      return;
    }
    if (_g1TestDate != null && _g1TestDate!.isBefore(_today)) {
      _showInlineError('Test date cannot be in the past.');
      return;
    }
    final locations = <Map<String, String>>[];
    if (!_pickupPreference) {
      if (_homeLocationSelected) {
        final address = _homeLocationController.text.trim();
        if (address.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enter your Home address.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        locations.add({'type': 'Home', 'label': 'Home', 'address': address});
      }
      if (_officeLocationSelected) {
        final address = _officeLocationController.text.trim();
        if (address.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enter your Work address.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        locations.add({'type': 'Work', 'label': 'Work', 'address': address});
      }
      if (_otherLocationSelected) {
        final label = _otherLocationLabelController.text.trim();
        final address = _otherLocationAddressController.text.trim();
        if (label.isEmpty || address.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Provide both a label and address for the Gym/Other location.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        locations.add({'type': 'Other', 'label': label, 'address': address});
      }
    }

    setState(() => _isSaving = true);

    try {
      final uploadedProfileImageUrl = await _uploadPendingProfilePhoto(userId);
      final profileUpdates = <String, dynamic>{
        'role': 'learner',
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
      };
      if (uploadedProfileImageUrl != null) {
        profileUpdates['profile_image_url'] = uploadedProfileImageUrl;
      }
      final licenceNumber = _licenceNumberController.text.trim();
      if (!_licenceNumberLocked && licenceNumber.isNotEmpty) {
        final available = await SupabaseService.isLicenceNumberAvailable(
          licenceNumber,
        );
        if (!available) {
          throw Exception(
              'That licence number is already attached to an account.');
        }
        profileUpdates['licence_number'] = OntarioLicence.format(licenceNumber);
      }
      if (_licenceExpiryDate != null) {
        profileUpdates['licence_expiry'] =
            _licenceExpiryDate!.toIso8601String();
      }
      if (_selectedCity != null && _selectedCity!.trim().isNotEmpty) {
        profileUpdates['city'] = _selectedCity!.trim();
      }
      if (age != null) {
        profileUpdates['age'] = age;
      }
      if (_selectedGender != null && _selectedGender!.trim().isNotEmpty) {
        profileUpdates['gender'] = _selectedGender!.trim();
      }

      await SupabaseService.updateProfileFields(userId, profileUpdates);

      await SupabaseService.upsertLearnerProfile(
        userId: userId,
        classesTakenSoFar: classesTaken,
        lastClassDate: _lastClassDate,
        targetTestDate: _g1TestDate,
        preferredLocations:
            locations.map((entry) => Map<String, dynamic>.from(entry)).toList(),
        transmissionPreference: _learnerTransmission,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Learner profile updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update profile: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveInstructorProfile() async {
    if ((_pendingProfileImagePath == null ||
            _pendingProfileImagePath!.trim().isEmpty) &&
        (_profileImageUrl == null || _profileImageUrl!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a profile photo to continue.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_licenceExpiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a licence expiry date.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_vehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one vehicle you teach with.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_vehicles.any((vehicle) => !vehicle.hasPhoto)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Every instructor vehicle must include a photo.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_pickupPreference &&
        !_homeLocationSelected &&
        !_officeLocationSelected &&
        !_otherLocationSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one preferred lesson location.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final selectedOfferings = _selectedOfferings.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedOfferings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one offering.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final rates = <String, double>{};
    for (final code in selectedOfferings) {
      final controller = _rateControllers[code];
      final value = controller?.text.trim();
      final parsed = value != null ? double.tryParse(value) : null;
      if (parsed == null || parsed <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Enter a valid hourly rate for ${_labelForOffering(code)}.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (parsed < _minimumInstructorLessonRate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Minimum lesson rate is \$40/hr.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      rates[code] = parsed;
    }

    final age = int.tryParse(_instructorAgeController.text.trim());
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = OntarioPhoneNumber.toE164(_phoneController.text);
    if (age != null && age < 21) {
      _showInlineError('Instructors must be at least 21 years old.');
      return;
    }
    final languages = _languagesController.text
        .split(',')
        .map((value) => _titleCase(value))
        .where((value) => value.isNotEmpty)
        .toList();

    final locations = <Map<String, String>>[];
    if (!_pickupPreference) {
      if (_homeLocationSelected) {
        final address = _homeLocationController.text.trim();
        if (address.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enter your Home address.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        locations.add({'type': 'Home', 'label': 'Home', 'address': address});
      }
      if (_officeLocationSelected) {
        final address = _officeLocationController.text.trim();
        if (address.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enter your Work address.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        locations.add({'type': 'Work', 'label': 'Work', 'address': address});
      }
      if (_otherLocationSelected) {
        final label = _otherLocationLabelController.text.trim();
        final address = _otherLocationAddressController.text.trim();
        if (label.isEmpty || address.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Provide both a label and address for the Gym/Other location.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        locations.add({'type': 'Other', 'label': label, 'address': address});
      }
    }

    setState(() => _isSaving = true);

    try {
      final uploadedProfileImageUrl = await _uploadPendingProfilePhoto(userId);
      final profileUpdates = <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'languages': languages.isNotEmpty ? languages : null,
      };
      if (uploadedProfileImageUrl != null) {
        profileUpdates['profile_image_url'] = uploadedProfileImageUrl;
      }

      final licenceNumber = _licenceNumberController.text.trim();
      if (!_licenceNumberLocked && licenceNumber.isNotEmpty) {
        final available = await SupabaseService.isLicenceNumberAvailable(
          licenceNumber,
        );
        if (!available) {
          throw Exception(
              'That licence number is already attached to an account.');
        }
        profileUpdates['licence_number'] = OntarioLicence.format(licenceNumber);
      }
      if (_licenceExpiryDate != null) {
        profileUpdates['licence_expiry'] =
            _licenceExpiryDate!.toIso8601String();
      }
      if (age != null) {
        profileUpdates['age'] = age;
      }
      if (_instructorGender != null && _instructorGender!.trim().isNotEmpty) {
        profileUpdates['gender'] = _instructorGender!.trim();
      }

      _instructorSelectedCity = (_instructorSelectedCity != null &&
              _instructorSelectedCity!.trim().isNotEmpty)
          ? _instructorSelectedCity!.trim()
          : null;
      final profileCity = _instructorSelectedCity ?? '';

      if (profileCity.isNotEmpty) {
        profileUpdates['city'] = profileCity;
      }

      await SupabaseService.updateProfileFields(userId, profileUpdates);

      final preparedVehicles = await _prepareVehiclesForUpload(userId);
      if (mounted) {
        setState(() {
          _vehicles
            ..clear()
            ..addAll(preparedVehicles);
        });
      }

      final vehiclePayload = preparedVehicles.map((vehicle) {
        final map = {
          'type': vehicle.type,
          'year': vehicle.year,
          'make': vehicle.make,
          'model': vehicle.model,
          'numberPlate': vehicle.numberPlate,
        };
        final transmission = vehicle.transmission;
        if (transmission != null && transmission.isNotEmpty) {
          map['transmission'] = transmission;
        }
        if (vehicle.photoUrl != null && vehicle.photoUrl!.isNotEmpty) {
          map['photoUrl'] = vehicle.photoUrl!;
        }
        return map;
      }).toList();
      final locationPayload =
          locations.map((entry) => Map<String, dynamic>.from(entry)).toList();
      final yearsExperience = int.tryParse(
        _yearsExperienceController.text.trim(),
      );
      if (yearsExperience != null) {
        if (yearsExperience < 0) {
          throw Exception('Years of experience cannot be negative.');
        }
        if (age != null && yearsExperience > age) {
          throw Exception('Years of experience cannot be greater than age.');
        }
        if (yearsExperience > 80) {
          throw Exception('Enter a realistic number of years of experience.');
        }
      }

      await SupabaseService.upsertInstructorProfile(
        userId: userId,
        bio: _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : null,
        defaultRate: rates.isNotEmpty ? rates.values.first : null,
        vehicles: vehiclePayload,
        offerings: selectedOfferings,
        offeringRates: rates,
        preferredLocations: _pickupPreference ? null : locationPayload,
        clearPreferredLocations: _pickupPreference,
        yearsOfExperience: yearsExperience,
        pickupPreference: _pickupPreference,
        transmissionPreference: preparedVehicles.isNotEmpty
            ? preparedVehicles.first.transmission
            : null,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Instructor profile updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      } else {
        context.go(AppRoutes.instructorHome);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update profile: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickDate({
    required TextEditingController controller,
    required DateTime? currentValue,
    required ValueChanged<DateTime> onSelected,
    DateTime? firstDate,
    DateTime? lastDate,
    bool preferLatestInitial = false,
  }) async {
    final earliest = firstDate == null
        ? DateTime(1970)
        : DateTime(firstDate.year, firstDate.month, firstDate.day);
    final latest = lastDate == null
        ? DateTime(2100)
        : DateTime(lastDate.year, lastDate.month, lastDate.day);
    final initial = currentValue != null &&
            !currentValue.isBefore(earliest) &&
            !currentValue.isAfter(latest)
        ? currentValue
        : preferLatestInitial
            ? latest
            : earliest.isAfter(latest)
                ? latest
                : earliest;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: earliest,
      lastDate: latest,
    );

    if (picked != null) {
      onSelected(picked);
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryBlue,
      ),
    );
  }

  String _labelForOffering(String code) {
    final match = _offeringOptions.firstWhere(
      (option) => option.code == code,
      orElse: () => const _OfferingOption(code: '', label: ''),
    );
    return match.label.isNotEmpty ? match.label : code;
  }

  Future<void> _pickPendingVehicleImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _pendingVehicleImagePath = picked.path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to pick image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<String?> _uploadPendingProfilePhoto(String userId) async {
    final path = _pendingProfileImagePath;
    if (path == null || path.trim().isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('Profile photo is missing. Please choose it again.');
    }
    final url = await SupabaseService.uploadProfileImage(
      userId: userId,
      file: file,
    );
    if (url == null || url.isEmpty) {
      throw Exception('Profile photo upload failed.');
    }
    if (mounted) {
      setState(() {
        _profileImageUrl = url;
        _pendingProfileImagePath = null;
      });
    } else {
      _profileImageUrl = url;
      _pendingProfileImagePath = null;
    }
    return url;
  }

  void _handleAddVehicle() {
    final type = _selectedVehicleType?.trim();
    final year = _vehicleYearController.text.trim();
    final make = _vehicleMakeController.text.trim();
    final model = _vehicleModelController.text.trim();
    final plate = _vehiclePlateController.text.trim().toUpperCase();
    final transmission = _selectedVehicleTransmission;

    if (type == null || type.isEmpty) {
      _showInlineError('Select a vehicle type.');
      return;
    }

    if (year.isEmpty || year.length != 4 || int.tryParse(year) == null) {
      _showInlineError('Enter a valid 4-digit vehicle year.');
      return;
    }
    final parsedYear = int.parse(year);
    final maxVehicleYear = DateTime.now().year + 1;
    if (parsedYear < 1990 || parsedYear > maxVehicleYear) {
      _showInlineError(
          'Vehicle year must be between 1990 and $maxVehicleYear.');
      return;
    }

    if (make.isEmpty || model.isEmpty) {
      _showInlineError('Add both the vehicle make and model.');
      return;
    }

    if (plate.isEmpty) {
      _showInlineError('Number plate is required.');
      return;
    }
    if (transmission == null) {
      _showInlineError('Select automatic or manual transmission.');
      return;
    }
    if ((_pendingVehicleImagePath == null ||
            _pendingVehicleImagePath!.trim().isEmpty) &&
        (_editingVehiclePhotoUrl == null ||
            _editingVehiclePhotoUrl!.trim().isEmpty)) {
      _showInlineError('Add a vehicle photo before saving this vehicle.');
      return;
    }

    final duplicatePlate = _vehicles.asMap().entries.any(
          (entry) =>
              entry.key != _editingVehicleIndex &&
              entry.value.numberPlate.toUpperCase() == plate,
        );
    if (duplicatePlate) {
      _showInlineError('This number plate is already added.');
      return;
    }

    setState(() {
      final updatedVehicle = _VehicleEntry(
        type: type,
        year: year,
        make: make,
        model: model,
        numberPlate: plate,
        transmission: transmission,
        photoUrl: _editingVehiclePhotoUrl,
        localImagePath: _pendingVehicleImagePath,
      );
      final editingIndex = _editingVehicleIndex;
      if (editingIndex == null) {
        _vehicles.add(updatedVehicle);
      } else {
        _vehicles[editingIndex] = updatedVehicle;
      }
      _vehicleYearController.clear();
      _vehicleMakeController.clear();
      _vehicleModelController.clear();
      _vehiclePlateController.clear();
      _selectedVehicleTransmission = null;
      _pendingVehicleImagePath = null;
      _editingVehicleIndex = null;
      _editingVehiclePhotoUrl = null;
    });
  }

  void _beginEditingVehicle(_VehicleEntry vehicle) {
    final index = _vehicles.indexOf(vehicle);
    if (index < 0) return;
    setState(() {
      _editingVehicleIndex = index;
      _selectedVehicleType = vehicle.type;
      _selectedVehicleTransmission = vehicle.transmission;
      _vehicleYearController.text = vehicle.year;
      _vehicleMakeController.text = vehicle.make;
      _vehicleModelController.text = vehicle.model;
      _vehiclePlateController.text = vehicle.numberPlate;
      _pendingVehicleImagePath = vehicle.localImagePath;
      _editingVehiclePhotoUrl = vehicle.photoUrl;
    });
  }

  Future<List<_VehicleEntry>> _prepareVehiclesForUpload(String userId) async {
    final updated = <_VehicleEntry>[];
    for (var vehicleIndex = 0;
        vehicleIndex < _vehicles.length;
        vehicleIndex++) {
      final vehicle = _vehicles[vehicleIndex];
      var current = vehicle;
      final localPath = vehicle.localImagePath;
      if (localPath != null && localPath.trim().isNotEmpty) {
        final file = File(localPath);
        if (await file.exists()) {
          final url = await SupabaseService.uploadVehicleGalleryImage(
            userId: userId,
            file: file,
            vehicleSlot: vehicleIndex,
          );
          if (url != null && url.isNotEmpty) {
            current = current.copyWith(photoUrl: url, localImagePath: null);
          }
        }
      }
      updated.add(current);
    }
    return updated;
  }

  void _showInlineError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Widget _buildVehiclePhotoChip(_VehicleEntry vehicle) {
    const double size = 56;
    Widget? imageWidget;
    if (vehicle.localImagePath != null &&
        vehicle.localImagePath!.trim().isNotEmpty) {
      final file = File(vehicle.localImagePath!);
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
        );
      }
    } else if (vehicle.photoUrl != null &&
        vehicle.photoUrl!.trim().isNotEmpty) {
      imageWidget = Image.network(
        vehicle.photoUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.directions_car),
      );
    }

    if (imageWidget == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.directions_car, color: AppColors.primaryBlue),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: imageWidget,
    );
  }
}

class _VehicleEntry {
  const _VehicleEntry({
    required this.type,
    required this.year,
    required this.make,
    required this.model,
    required this.numberPlate,
    this.transmission,
    this.photoUrl,
    this.localImagePath,
  });

  final String type;
  final String year;
  final String make;
  final String model;
  final String numberPlate;
  final String? transmission;
  final String? photoUrl;
  final String? localImagePath;

  bool get hasPhoto =>
      (photoUrl != null && photoUrl!.trim().isNotEmpty) ||
      (localImagePath != null && localImagePath!.trim().isNotEmpty);

  _VehicleEntry copyWith({
    String? type,
    String? year,
    String? make,
    String? model,
    String? numberPlate,
    String? transmission,
    String? photoUrl,
    String? localImagePath,
  }) {
    return _VehicleEntry(
      type: type ?? this.type,
      year: year ?? this.year,
      make: make ?? this.make,
      model: model ?? this.model,
      numberPlate: numberPlate ?? this.numberPlate,
      transmission: transmission ?? this.transmission,
      photoUrl: photoUrl ?? this.photoUrl,
      localImagePath: localImagePath ?? this.localImagePath,
    );
  }
}

class _OfferingOption {
  const _OfferingOption({required this.code, required this.label});

  final String code;
  final String label;
}
