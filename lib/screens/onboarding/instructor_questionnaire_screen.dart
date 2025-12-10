import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';

class InstructorQuestionnaireScreen extends StatefulWidget {
  final String role;

  const InstructorQuestionnaireScreen({
    super.key,
    required this.role,
  });

  @override
  State<InstructorQuestionnaireScreen> createState() =>
      _InstructorQuestionnaireScreenState();
}

class _InstructorQuestionnaireScreenState
    extends State<InstructorQuestionnaireScreen> {
  final _formKey = GlobalKey<FormState>();

  final _licenceNumberController = TextEditingController();
  final _licenceExpiryController = TextEditingController();

  final _ageController = TextEditingController();

  DateTime? _licenceExpiry;

  String? _gender;

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
  final List<String> _transmissionOptions = const [
    'Automatic',
    'Manual',
  ];
  String? _selectedTransmission;
  final _vehicleYearController = TextEditingController();
  final _vehicleMakeController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehiclePlateController = TextEditingController();

  final List<_VehicleEntry> _vehicles = [];
  String? _pendingVehicleImagePath;
  final ImagePicker _imagePicker = ImagePicker();

  final List<_OfferingOption> _offeringOptions = const [
    _OfferingOption(code: 'G2', label: 'G2 Road Test'),
    _OfferingOption(code: 'G', label: 'G Road Test'),
    _OfferingOption(code: 'PR', label: 'Practice Sessions'),
  ];
  final Map<String, bool> _selectedOfferings = {};
  final Map<String, TextEditingController> _rateControllers = {};
  final _homeAddressController = TextEditingController();
  final _officeAddressController = TextEditingController();
  final _otherLabelController = TextEditingController();
  final _otherAddressController = TextEditingController();
  bool _pickupPreference = true;
  bool _homeSelected = false;
  bool _officeSelected = false;
  bool _otherSelected = false;

  @override
  void initState() {
    super.initState();
    for (final option in _offeringOptions) {
      _selectedOfferings[option.code] = false;
      _rateControllers[option.code] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _licenceNumberController.dispose();
    _licenceExpiryController.dispose();
    _ageController.dispose();
    _vehicleYearController.dispose();
    _vehicleMakeController.dispose();
    _vehicleModelController.dispose();
    _vehiclePlateController.dispose();
    _homeAddressController.dispose();
    _officeAddressController.dispose();
    _otherLabelController.dispose();
    _otherAddressController.dispose();
    for (final controller in _rateControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLicenceExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _licenceExpiry ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 10),
    );

    if (picked != null) {
      setState(() {
        _licenceExpiry = picked;
        _licenceExpiryController.text =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _resetVehicleInputs() {
    _vehicleYearController.clear();
    _vehicleMakeController.clear();
    _vehicleModelController.clear();
    _vehiclePlateController.clear();
  }

  Future<void> _pickVehicleImage() async {
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
        child: const Icon(
          Icons.directions_car,
          color: AppColors.primaryBlue,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: imageWidget,
    );
  }

  void _handleAddVehicle() {
    final type = _selectedVehicleType;
    final year = _vehicleYearController.text.trim();
    final make = _vehicleMakeController.text.trim();
    final model = _vehicleModelController.text.trim();
    final numberPlate = _vehiclePlateController.text.trim().toUpperCase();
    final transmission = _selectedTransmission;

    if (type == null || type.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a vehicle type.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (year.isEmpty || year.length != 4 || int.tryParse(year) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid 4-digit vehicle year.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (make.isEmpty || model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add both vehicle make and model.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (transmission == null || transmission.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select the vehicle transmission.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (numberPlate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Number plate is required.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final duplicatePlate = _vehicles.any(
      (vehicle) => vehicle.numberPlate.toUpperCase() == numberPlate,
    );

    if (duplicatePlate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This number plate is already added.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final entry = _VehicleEntry(
      type: type,
      year: year,
      make: make,
      model: model,
      numberPlate: numberPlate,
      transmission: transmission,
      localImagePath: _pendingVehicleImagePath,
    );

    setState(() {
      _vehicles.add(entry);
      _pendingVehicleImagePath = null;
    });
    _resetVehicleInputs();
    setState(() {
      _selectedTransmission = null;
    });
  }

  void _handleContinue() {
    if (!_formKey.currentState!.validate()) return;
    if (_licenceExpiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your licence expiry date.'),
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
    if (!_pickupPreference &&
        !_homeSelected &&
        !_officeSelected &&
        !_otherSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one preferred lesson location.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (!_selectedOfferings.values.any((selected) => selected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one type of offering.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final rates = <String, double>{};
    for (final entry in _selectedOfferings.entries) {
      if (!entry.value) continue;
      final controller = _rateControllers[entry.key];
      final value = controller?.text.trim();
      final parsed = value != null ? double.tryParse(value) : null;
      if (parsed == null || parsed <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please provide a valid hourly rate for ${entry.key}.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      rates[entry.key] = parsed;
    }

    List<Map<String, String>>? preferredLocations;
    if (!_pickupPreference) {
      final collected = <Map<String, String>>[];
      if (_homeSelected) {
        final address = _homeAddressController.text.trim();
        if (address.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enter your Home address.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        collected.add({'type': 'Home', 'label': 'Home', 'address': address});
      }
      if (_officeSelected) {
        final address = _officeAddressController.text.trim();
        if (address.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enter your Office address.'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
        collected
            .add({'type': 'Office', 'label': 'Office', 'address': address});
      }
      if (_otherSelected) {
        final label = _otherLabelController.text.trim();
        final address = _otherAddressController.text.trim();
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
        collected.add({'type': 'Other', 'label': label, 'address': address});
      }

      if (collected.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select at least one preferred lesson location.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      preferredLocations = collected;
    }

    final ageValue = int.tryParse(_ageController.text.trim());
    final profileData = <String, dynamic>{};
    if (ageValue != null) {
      profileData['age'] = ageValue;
    }
    if (_gender != null && _gender!.trim().isNotEmpty) {
      profileData['gender'] = _gender!.trim();
    }

    final locationPayload = preferredLocations
        ?.map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    final instructorProfileData = <String, dynamic>{
      'vehicles': _vehicles
          .map((vehicle) {
            final map = {
              'type': vehicle.type,
              'year': vehicle.year,
              'make': vehicle.make,
              'model': vehicle.model,
              'numberPlate': vehicle.numberPlate,
              'transmission': vehicle.transmission,
            };
            if (vehicle.photoUrl != null && vehicle.photoUrl!.isNotEmpty) {
              map['photoUrl'] = vehicle.photoUrl!;
            }
            if (vehicle.localImagePath != null &&
                vehicle.localImagePath!.isNotEmpty) {
              map['localImagePath'] = vehicle.localImagePath!;
            }
            return map;
          })
          .toList(),
      'offerings': _selectedOfferings.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList(),
      'offering_rates': rates,
      'pickup_preference': _pickupPreference,
    };
    if (locationPayload != null) {
      instructorProfileData['preferred_locations'] = locationPayload;
    }
    if (rates.isNotEmpty) {
      instructorProfileData['default_rate'] = rates.values.first;
    }
    final questionnaireData = <String, dynamic>{
      'profile': profileData,
      'instructorProfile': instructorProfileData,
    };

    context.go(
      AppRoutes.licenseInfo,
      extra: {
        'role': widget.role,
        'initialLicenceNumber': _licenceNumberController.text.trim(),
        'initialLicenceExpiry': _licenceExpiry?.toIso8601String(),
        'questionnaire': questionnaireData,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instructor Questionnaire'),
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.golden.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Please ensure all licence details match your instructor certification.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Driving Licence',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _licenceNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Licence Number',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Licence number is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _licenceExpiryController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Licence Expiry',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: _pickLicenceExpiry,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Vehicles',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedVehicleType,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _vehicleTypes
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedVehicleType = value;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedTransmission,
                  decoration: const InputDecoration(
                    labelText: 'Transmission',
                    border: OutlineInputBorder(),
                  ),
                  items: _transmissionOptions
                      .map(
                        (option) => DropdownMenuItem(
                          value: option,
                          child: Text(option),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _selectedTransmission = value;
                  }),
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
                          labelText: 'Company / Make',
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
                  decoration: const InputDecoration(
                    labelText: 'Number Plate',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickVehicleImage,
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
                    label: const Text('Add vehicle'),
                  ),
                ),
                if (_vehicles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      for (final vehicle in _vehicles)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildVehiclePhotoChip(vehicle),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${vehicle.type} - ${vehicle.year} ${vehicle.make} ${vehicle.model}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Plate: ${vehicle.numberPlate}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    if (vehicle.transmission.isNotEmpty)
                                      Text(
                                        'Transmission: ${vehicle.transmission}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    if (vehicle.hasPhoto)
                                      Text(
                                        'Photo attached',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Remove vehicle',
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _vehicles.remove(vehicle);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Pickup Preference',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Would you prefer to pick up the learner from their location?',
                  ),
                  subtitle: Text(_pickupPreference ? 'Yes' : 'No'),
                  value: _pickupPreference,
                  activeColor: AppColors.primaryBlue,
                  onChanged: (value) {
                    setState(() {
                      _pickupPreference = value;
                      if (value) {
                        _homeSelected = false;
                        _officeSelected = false;
                        _otherSelected = false;
                        _homeAddressController.clear();
                        _officeAddressController.clear();
                        _otherLabelController.clear();
                        _otherAddressController.clear();
                      }
                    });
                  },
                ),
                if (!_pickupPreference) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Preferred Lesson Locations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('Home'),
                    value: _homeSelected,
                    onChanged: (value) {
                      setState(() {
                        _homeSelected = value ?? false;
                        if (!_homeSelected) {
                          _homeAddressController.clear();
                        }
                      });
                    },
                  ),
                  if (_homeSelected)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 12),
                      child: TextField(
                        controller: _homeAddressController,
                        decoration: const InputDecoration(
                          labelText: 'Home Address',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  CheckboxListTile(
                    title: const Text('Office'),
                    value: _officeSelected,
                    onChanged: (value) {
                      setState(() {
                        _officeSelected = value ?? false;
                        if (!_officeSelected) {
                          _officeAddressController.clear();
                        }
                      });
                    },
                  ),
                  if (_officeSelected)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 12),
                      child: TextField(
                        controller: _officeAddressController,
                        decoration: const InputDecoration(
                          labelText: 'Office Address',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  CheckboxListTile(
                    title: const Text('Other'),
                    value: _otherSelected,
                    onChanged: (value) {
                      setState(() {
                        _otherSelected = value ?? false;
                        if (!_otherSelected) {
                          _otherLabelController.clear();
                          _otherAddressController.clear();
                        }
                      });
                    },
                  ),
                  if (_otherSelected) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 12),
                      child: TextField(
                        controller: _otherLabelController,
                        decoration: const InputDecoration(
                          labelText: 'Location Label',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 12),
                      child: TextField(
                        controller: _otherAddressController,
                        decoration: const InputDecoration(
                          labelText: 'Location Address',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                const Text(
                  'Personal Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
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
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Female',
                      child: Text('Female'),
                    ),
                    DropdownMenuItem(
                      value: 'Male',
                      child: Text('Male'),
                    ),
                    DropdownMenuItem(
                      value: 'Non-binary',
                      child: Text('Non-binary'),
                    ),
                    DropdownMenuItem(
                      value: 'Prefer not to say',
                      child: Text('Prefer not to say'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _gender = value),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a gender option';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Offerings & Rates',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 12),
                Column(
                  children: _offeringOptions.map((option) {
                    final isSelected = _selectedOfferings[option.code] ?? false;
                    final rateController = _rateControllers[option.code]!;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(option.label),
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                _selectedOfferings[option.code] =
                                    value ?? false;
                                if (!(value ?? false)) {
                                  rateController.clear();
                                }
                              });
                            },
                          ),
                          if (isSelected)
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: TextField(
                                controller: rateController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Hourly Rate (\$)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.golden,
                      foregroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Continue',
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

class _VehicleEntry {
  final String type;
  final String year;
  final String make;
  final String model;
  final String numberPlate;
  final String transmission;
  final String? photoUrl;
  final String? localImagePath;

  bool get hasPhoto =>
      (photoUrl != null && photoUrl!.trim().isNotEmpty) ||
      (localImagePath != null && localImagePath!.trim().isNotEmpty);

  const _VehicleEntry({
    required this.type,
    required this.year,
    required this.make,
    required this.model,
    required this.numberPlate,
    required this.transmission,
    this.photoUrl,
    this.localImagePath,
  });
}

class _OfferingOption {
  final String code;
  final String label;

  const _OfferingOption({
    required this.code,
    required this.label,
  });
}
