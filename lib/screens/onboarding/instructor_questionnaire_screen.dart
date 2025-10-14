import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
  final _vehicleYearController = TextEditingController();
  final _vehicleMakeController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehiclePlateController = TextEditingController();

  final List<_VehicleEntry> _vehicles = [];
  final List<_AreaOption> _areas = [];

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

  void _handleAddVehicle() {
    final type = _selectedVehicleType;
    final year = _vehicleYearController.text.trim();
    final make = _vehicleMakeController.text.trim();
    final model = _vehicleModelController.text.trim();
    final numberPlate = _vehiclePlateController.text.trim().toUpperCase();

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
    );

    setState(() {
      _vehicles.add(entry);
    });
    _resetVehicleInputs();
  }

  Future<void> _showAddAreaDialog() async {
    final cityController = TextEditingController();
    final radiusController = TextEditingController();

    final result = await showDialog<_AreaOption>(
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final city = cityController.text.trim();
                final radius = double.tryParse(radiusController.text.trim());
                if (city.isEmpty || radius == null || radius <= 0) {
                  return;
                }
                Navigator.of(context)
                    .pop(_AreaOption(city: city, radiusKm: radius));
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      setState(() => _areas.add(result));
    }
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
    if (_areas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one area you operate in.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (!_homeSelected && !_officeSelected && !_otherSelected) {
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

    final locations = <Map<String, String>>[];
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
      locations.add({'type': 'Home', 'label': 'Home', 'address': address});
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
      locations.add({'type': 'Office', 'label': 'Office', 'address': address});
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
      locations.add({'type': 'Other', 'label': label, 'address': address});
    }

    if (locations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one preferred lesson location.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final questionnaireData = <String, dynamic>{
      'vehicles': _vehicles
          .map((vehicle) => {
                'type': vehicle.type,
                'year': vehicle.year,
                'make': vehicle.make,
                'model': vehicle.model,
                'numberPlate': vehicle.numberPlate,
              })
          .toList(),
      'areas': _areas
          .map((area) => {
                'city': area.city,
                'radiusKm': area.radiusKm,
              })
          .toList(),
      'age': int.tryParse(_ageController.text.trim()),
      'gender': _gender,
      'offerings': _selectedOfferings.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList(),
      'offeringRates': rates,
      'locations': locations,
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
                    color: AppColors.accentYellow.withOpacity(0.12),
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
                  value: _selectedVehicleType,
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
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${vehicle.type} • ${vehicle.year} ${vehicle.make} ${vehicle.model}',
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
                  'Areas of Operation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_areas.isEmpty)
                      const Text(
                        'No service areas added yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    for (final area in _areas)
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${area.city} • ${area.radiusKm} km radius'),
                            IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: 'Remove',
                              onPressed: () {
                                setState(() => _areas.remove(area));
                              },
                            ),
                          ],
                        ),
                      ),
                    TextButton.icon(
                      onPressed: _showAddAreaDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add service area'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
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
                  value: _gender,
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
                      backgroundColor: AppColors.accentYellow,
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

  const _VehicleEntry({
    required this.type,
    required this.year,
    required this.make,
    required this.model,
    required this.numberPlate,
  });
}

class _AreaOption {
  final String city;
  final double radiusKm;

  const _AreaOption({
    required this.city,
    required this.radiusKm,
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
