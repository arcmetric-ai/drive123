import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants/app_colors.dart';
import '../../services/supabase_service.dart';

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
  final _licenceNumberController = TextEditingController();
  final _licenceExpiryController = TextEditingController();
  DateTime? _licenceExpiryDate;

  // Learner fields
  final _g1TestDateController = TextEditingController();
  final _cityController = TextEditingController();
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

  // Instructor fields
  final _instructorAgeController = TextEditingController();
  String? _instructorGender;

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
  final _vehicleYearController = TextEditingController();
  final _vehicleMakeController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final List<_VehicleEntry> _vehicles = [];

  final List<_AreaEntry> _areas = [];
  final _serviceAreaController = TextEditingController();
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
    _OfferingOption(code: 'PR', label: 'Practice Sessions'),
  ];
  final Map<String, bool> _selectedOfferings = {};
  final Map<String, TextEditingController> _rateControllers = {};

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
    _cityController.dispose();
    _ageController.dispose();
    _classesTakenController.dispose();
    _lastClassDateController.dispose();
    _instructorAgeController.dispose();
    _vehicleYearController.dispose();
    _vehicleMakeController.dispose();
    _vehicleModelController.dispose();
    _vehiclePlateController.dispose();
    _serviceAreaController.dispose();
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
      final firstName = (rawProfile?['first_name'] as String?) ??
          (currentUser.userMetadata?['first_name'] as String?) ??
          '';
      final lastName = (rawProfile?['last_name'] as String?) ??
          (currentUser.userMetadata?['last_name'] as String?) ??
          '';
      final phone = (rawProfile?['phone'] as String?) ??
          (currentUser.userMetadata?['phone'] as String?) ??
          '';
      _email = (rawProfile?['email'] as String?) ?? currentUser.email ?? '';
      _firstNameController.text = firstName;
      _lastNameController.text = lastName;
      _phoneController.text = phone;

      final role =
          (rawProfile?['role'] as String?) ?? currentUser.userMetadata?['role'];
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

    final licenceNumber = detail['licence_number'] as String?;
    final licenceExpiry = detail['licence_expiry'] as String?;
    final testDate = detail['g1_test_date'] as String?;
    final lastClass = detail['last_class_date'] as String?;

    _licenceNumberController.text = licenceNumber ?? '';
    if (licenceExpiry != null) {
      final parsed = DateTime.tryParse(licenceExpiry);
      if (parsed != null) {
        _licenceExpiryDate = parsed;
        _licenceExpiryController.text = DateFormat('yyyy-MM-dd').format(parsed);
      }
    }

    if (testDate != null) {
      final parsed = DateTime.tryParse(testDate);
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

    _cityController.text = (detail['city'] as String?) ?? '';
    final age = detail['age'];
    if (age is int) {
      _ageController.text = age.toString();
    } else if (age is String) {
      _ageController.text = age;
    }

    final gender = detail['gender'];
    if (gender is String && gender.isNotEmpty) {
      _selectedGender = gender;
    } else {
      _selectedGender = null;
    }

    final classesTaken = detail['classes_taken_total'];
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
          final type = (entry['type'] as String?)?.toLowerCase();
          final label = entry['label'] as String?;
          final address = entry['address'] as String?;
          if (type == 'home') {
            _homeLocationSelected = true;
            _homeLocationController.text = address ?? '';
          } else if (type == 'office') {
            _officeLocationSelected = true;
            _officeLocationController.text = address ?? '';
          } else if (type == 'other') {
            _otherLocationSelected = true;
            _otherLocationLabelController.text = label ?? '';
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
    _areas.clear();

    final licenceNumber = detail['licence_number'] as String?;
    final licenceExpiry = detail['licence_expiry'] as String?;

    _licenceNumberController.text = licenceNumber ?? '';
    if (licenceExpiry != null) {
      final parsed = DateTime.tryParse(licenceExpiry);
      if (parsed != null) {
        _licenceExpiryDate = parsed;
        _licenceExpiryController.text = DateFormat('yyyy-MM-dd').format(parsed);
      }
    }

    final age = detail['age'];
    if (age is int) {
      _instructorAgeController.text = age.toString();
    } else if (age is String) {
      _instructorAgeController.text = age;
    }

    final gender = detail['gender'];
    if (gender is String && gender.isNotEmpty) {
      _instructorGender = gender;
    } else {
      _instructorGender = null;
    }

    _serviceAreaController.text = (detail['service_area'] as String?) ?? '';
    _bioController.text = (detail['bio'] as String?) ?? '';

    final vehicles = detail['vehicles'];
    if (vehicles is List) {
      for (final entry in vehicles) {
        if (entry is Map) {
          final type = entry['type'] as String?;
          final year = entry['year'] as String?;
          final make = entry['make'] as String?;
          final model = entry['model'] as String?;
          final plate = entry['numberPlate'] as String?;

          if (type != null &&
              year != null &&
              make != null &&
              model != null &&
              plate != null) {
            _vehicles.add(
              _VehicleEntry(
                type: type,
                year: year,
                make: make,
                model: model,
                numberPlate: plate,
              ),
            );
          }
        }
      }
    }

    final areas = detail['areas_of_operation'];
    if (areas is List) {
      for (final entry in areas) {
        if (entry is Map) {
          final city = entry['city'] as String?;
          final radius = entry['radiusKm'];
          double? parsedRadius;
          if (radius is num) {
            parsedRadius = radius.toDouble();
          } else if (radius is String) {
            parsedRadius = double.tryParse(radius);
          }
          if (city != null && parsedRadius != null) {
            _areas.add(_AreaEntry(city: city, radiusKm: parsedRadius));
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

    final languages = detail['languages'];
    if (languages is List) {
      _languagesController.text = languages.whereType<String>().join(', ');
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
          final type = (entry['type'] as String?)?.toLowerCase();
          final label = entry['label'] as String?;
          final address = entry['address'] as String?;
          if (type == 'home') {
            _homeLocationSelected = true;
            _homeLocationController.text = address ?? '';
          } else if (type == 'office') {
            _officeLocationSelected = true;
            _officeLocationController.text = address ?? '';
          } else if (type == 'other') {
            _otherLocationSelected = true;
            _otherLocationLabelController.text = label ?? '';
            _otherLocationAddressController.text = address ?? '';
          }
        }
      }
    }
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
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearnerForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('G1 Licence Details'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _licenceNumberController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'G1 Licence Number',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Licence number is required';
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
            onSelected: (value) => setState(() {
              _licenceExpiryDate = value;
            }),
          ),
          validator: (value) {
            if ((value ?? '').isEmpty) {
              return 'Select an expiry date';
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
            onSelected: (value) => setState(() {
              _g1TestDate = value;
            }),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Personal Details'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _cityController,
          decoration: const InputDecoration(
            labelText: 'City',
            border: OutlineInputBorder(),
          ),
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
            return null;
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedGender,
          items: _genderOptions
              .map(
                (gender) => DropdownMenuItem(
                  value: gender,
                  child: Text(gender),
                ),
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
          title: const Text('Office'),
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
                labelText: 'Office Address',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        CheckboxListTile(
          title: const Text('Other'),
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
                labelText: 'Location Label',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            child: TextField(
              controller: _otherLocationAddressController,
              decoration: const InputDecoration(
                labelText: 'Location Address',
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
            labelText: 'How many classes have you taken?',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Let us know how many classes you have taken';
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
        _buildSectionTitle('Instructor Licence'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _licenceNumberController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Licence Number',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Licence number is required';
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
            onSelected: (value) => setState(() {
              _licenceExpiryDate = value;
            }),
          ),
          validator: (value) {
            if ((value ?? '').isEmpty) {
              return 'Select an expiry date';
            }
            return null;
          },
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Professional Profile'),
        const SizedBox(height: 12),
        TextFormField(
          controller: _serviceAreaController,
          decoration: const InputDecoration(
            labelText: 'Primary Service Area',
            border: OutlineInputBorder(),
          ),
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
          title: const Text('Office'),
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
                labelText: 'Office Address',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        CheckboxListTile(
          title: const Text('Other'),
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
                labelText: 'Location Label',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            child: TextField(
              controller: _otherLocationAddressController,
              decoration: const InputDecoration(
                labelText: 'Location Address',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        _buildSectionTitle('Vehicles'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _selectedVehicleType,
          items: _vehicleTypes
              .map(
                (type) => DropdownMenuItem(
                  value: type,
                  child: Text(type),
                ),
              )
              .toList(),
          decoration: const InputDecoration(
            labelText: 'Vehicle Type',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _selectedVehicleType = value),
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
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _handleAddVehicle,
            icon: const Icon(Icons.add),
            label: const Text('Add vehicle'),
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
                      title: Text(
                        '${vehicle.type} • ${vehicle.year} ${vehicle.make} ${vehicle.model}',
                      ),
                      subtitle: Text('Plate: ${vehicle.numberPlate}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _vehicles.remove(vehicle);
                        }),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 24),
        _buildSectionTitle('Areas of Operation'),
        const SizedBox(height: 12),
        if (_areas.isEmpty)
          Text(
            'No areas added yet. Add the cities you operate in and your radius.',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        Column(
          children: _areas
              .map(
                (area) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(area.city),
                    subtitle: Text('Radius: ${area.radiusKm} km'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _areas.remove(area);
                      }),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _showAddAreaDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add service area'),
          ),
        ),
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
            return null;
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _instructorGender,
          items: _genderOptions
              .map(
                (gender) => DropdownMenuItem(
                  value: gender,
                  child: Text(gender),
                ),
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
                            decimal: true),
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
    if (_licenceExpiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a licence expiry date.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_homeLocationSelected &&
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
    final classesTaken = int.tryParse(_classesTakenController.text.trim());
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    final locations = <Map<String, String>>[];
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
            content: Text('Enter your Office address.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      locations.add({'type': 'Office', 'label': 'Office', 'address': address});
    }
    if (_otherLocationSelected) {
      final label = _otherLocationLabelController.text.trim();
      final address = _otherLocationAddressController.text.trim();
      if (label.isEmpty || address.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Provide both a label and address for the other location.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      locations.add({'type': 'Other', 'label': label, 'address': address});
    }

    setState(() => _isSaving = true);

    try {
      await SupabaseService.updateProfileFields(userId, {
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone.isNotEmpty ? phone : null,
      });

      await SupabaseService.upsertLearnerProfile(
        userId: userId,
        licenceNumber: _licenceNumberController.text.trim(),
        licenceExpiry: _licenceExpiryDate,
        city: _cityController.text.trim(),
        age: age,
        gender: _selectedGender,
        classesTaken: classesTaken,
        lastClassDate: _lastClassDate,
        g1TestDate: _g1TestDate,
        preferredLocations: locations
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Learner profile updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
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

    if (_areas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one area of operation.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_homeLocationSelected &&
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
                'Enter a valid hourly rate for ${_labelForOffering(code)}.'),
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
    final phone = _phoneController.text.trim();
    final languages = _languagesController.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    final locations = <Map<String, String>>[];
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
            content: Text('Enter your Office address.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      locations.add({'type': 'Office', 'label': 'Office', 'address': address});
    }
    if (_otherLocationSelected) {
      final label = _otherLocationLabelController.text.trim();
      final address = _otherLocationAddressController.text.trim();
      if (label.isEmpty || address.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Provide both a label and address for the other location.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      locations.add({'type': 'Other', 'label': label, 'address': address});
    }

    setState(() => _isSaving = true);

    try {
      await SupabaseService.updateProfileFields(userId, {
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone.isNotEmpty ? phone : null,
      });

      await SupabaseService.upsertInstructorProfile(
        userId: userId,
        licenceNumber: _licenceNumberController.text.trim(),
        licenceExpiry: _licenceExpiryDate,
        serviceArea: _serviceAreaController.text.trim().isNotEmpty
            ? _serviceAreaController.text.trim()
            : null,
        bio: _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : null,
        age: age,
        gender: _instructorGender,
        vehicles: _vehicles
            .map(
              (vehicle) => {
                'type': vehicle.type,
                'year': vehicle.year,
                'make': vehicle.make,
                'model': vehicle.model,
                'numberPlate': vehicle.numberPlate,
              },
            )
            .toList(),
        areasOfOperation: _areas
            .map(
              (area) => {
                'city': area.city,
                'radiusKm': area.radiusKm,
              },
            )
            .toList(),
        offerings: selectedOfferings,
        offeringRates: rates,
        preferredLocations:
            locations.map((entry) => Map<String, dynamic>.from(entry)).toList(),
        languages: languages.isEmpty ? null : languages,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Instructor profile updated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
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
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentValue ?? DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      onSelected(picked);
      controller.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  void _handleAddVehicle() {
    final type = _selectedVehicleType?.trim();
    final year = _vehicleYearController.text.trim();
    final make = _vehicleMakeController.text.trim();
    final model = _vehicleModelController.text.trim();
    final plate = _vehiclePlateController.text.trim().toUpperCase();

    if (type == null || type.isEmpty) {
      _showInlineError('Select a vehicle type.');
      return;
    }

    if (year.isEmpty || year.length != 4 || int.tryParse(year) == null) {
      _showInlineError('Enter a valid 4-digit vehicle year.');
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

    final duplicatePlate = _vehicles.any(
      (vehicle) => vehicle.numberPlate.toUpperCase() == plate,
    );
    if (duplicatePlate) {
      _showInlineError('This number plate is already added.');
      return;
    }

    setState(() {
      _vehicles.add(
        _VehicleEntry(
          type: type,
          year: year,
          make: make,
          model: model,
          numberPlate: plate,
        ),
      );
      _vehicleYearController.clear();
      _vehicleMakeController.clear();
      _vehicleModelController.clear();
      _vehiclePlateController.clear();
    });
  }

  void _showInlineError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _showAddAreaDialog() async {
    final cityController = TextEditingController();
    final radiusController = TextEditingController();

    final result = await showDialog<_AreaEntry>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Service Area'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: cityController,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: radiusController,
                decoration: const InputDecoration(
                  labelText: 'Radius (km)',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final city = cityController.text.trim();
                final radius = double.tryParse(radiusController.text.trim());
                if (city.isEmpty || radius == null || radius <= 0) {
                  return;
                }
                Navigator.pop(
                    context, _AreaEntry(city: city, radiusKm: radius));
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        _areas.add(result);
      });
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
}

class _VehicleEntry {
  const _VehicleEntry({
    required this.type,
    required this.year,
    required this.make,
    required this.model,
    required this.numberPlate,
  });

  final String type;
  final String year;
  final String make;
  final String model;
  final String numberPlate;
}

class _AreaEntry {
  const _AreaEntry({
    required this.city,
    required this.radiusKm,
  });

  final String city;
  final double radiusKm;
}

class _OfferingOption {
  const _OfferingOption({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}
