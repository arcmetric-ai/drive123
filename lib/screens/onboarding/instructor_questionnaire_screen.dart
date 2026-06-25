import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../utils/ontario_phone_number.dart';

const Color _qBg = Color(0xFFF1F3F6);
const Color _qCardBg = Colors.white;
const Color _qBorder = Color(0xFFE2E8F0);
const Color _qPrimary = Color(0xFF2F8BE6);
const Color _qText = Color(0xFF0F172A);
const Color _qMuted = Color(0xFF5C6472);
const double _minimumInstructorLessonRate = 40;

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

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenceNumberController = TextEditingController();
  final _licenceExpiryController = TextEditingController();

  final _ageController = TextEditingController();
  String? _profileImagePath;

  DateTime? _licenceExpiry;

  String? _gender;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

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
    _OfferingOption(code: 'PR', label: 'Refresher Lessons'),
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
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
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _licenceExpiry != null && !_licenceExpiry!.isBefore(today)
          ? _licenceExpiry!
          : today,
      firstDate: today,
      lastDate: DateTime(today.year + 10),
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

  Future<void> _pickVehicleImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
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

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked != null) {
        setState(() => _profileImagePath = picked.path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to pick profile photo: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _chooseVehicleImageSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add vehicle photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _qText,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from photos'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null) return;
    await _pickVehicleImage(source);
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
    final parsedYear = int.parse(year);
    final maxVehicleYear = DateTime.now().year + 1;
    if (parsedYear < 1990 || parsedYear > maxVehicleYear) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Vehicle year must be between 1990 and $maxVehicleYear.'),
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

    if (_pendingVehicleImagePath == null ||
        _pendingVehicleImagePath!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a vehicle photo before adding this vehicle.'),
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
    if (_profileImagePath == null || _profileImagePath!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a profile photo to continue.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_licenceExpiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your licence expiry date.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_licenceExpiry!.isBefore(_today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Licence expiry cannot be in the past.'),
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
      if (parsed < _minimumInstructorLessonRate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Minimum lesson rate is \$40/hr.'),
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
    if (ageValue == null || ageValue < 21 || ageValue > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Instructors must be between 21 and 100 years old.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    final profileData = <String, dynamic>{};
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = OntarioPhoneNumber.toE164(_phoneController.text);
    if (firstName.isNotEmpty) {
      profileData['first_name'] = firstName;
    }
    if (lastName.isNotEmpty) {
      profileData['last_name'] = lastName;
    }
    if (phone != null && phone.isNotEmpty) {
      profileData['phone'] = phone;
    }
    profileData['profileImageLocalPath'] = _profileImagePath;
    profileData['age'] = ageValue;
    if (_gender != null && _gender!.trim().isNotEmpty) {
      profileData['gender'] = _gender!.trim();
    }

    final locationPayload = preferredLocations
        ?.map((entry) => Map<String, dynamic>.from(entry))
        .toList();
    final instructorProfileData = <String, dynamic>{
      'vehicles': _vehicles.map((vehicle) {
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
      }).toList(),
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

  InputDecoration _fieldDecoration({
    required String label,
    Widget? suffixIcon,
    String? prefixText,
  }) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: _qBorder),
    );
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
      labelStyle: const TextStyle(
        color: _qMuted,
        fontSize: 15,
      ),
      filled: true,
      fillColor: _qCardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: border,
      enabledBorder: border,
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: _qPrimary, width: 1.4),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: AppColors.error, width: 1.4),
      ),
      suffixIcon: suffixIcon,
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: _qCardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _qBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: _qText,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLocationOption({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _qBorder),
      ),
      child: CheckboxListTile(
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _qText,
          ),
        ),
        value: value,
        onChanged: onChanged,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        controlAffinity: ListTileControlAffinity.trailing,
        activeColor: _qPrimary,
      ),
    );
  }

  String? _validatePhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Phone number is required';
    }
    if (!OntarioPhoneNumber.isValid(trimmed)) {
      return 'Enter a valid 10-digit Ontario phone number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _qBg,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.roleSelection),
        ),
        title: const Text(
          'Instructor Questionnaire',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: _qText,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(17),
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(0xFFE4EBF7),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x14054ADA),
                                      blurRadius: 14,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(9),
                                child: SvgPicture.asset(
                                  'assets/images/DT_AppIcon (1).svg',
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'DriveTutor',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: _qPrimary,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                            decoration: BoxDecoration(
                              color: _qCardBg,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: _qBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4FBE8),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: const Color(0xFFCDEB8B),
                                    ),
                                  ),
                                  child: const Text(
                                    'Step 2 of 3',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _qText,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  'Instructor details',
                                  style: TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    color: _qText,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Please ensure all licence details match your instructor certification.',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    height: 1.4,
                                    color: Colors.black.withValues(alpha: 0.6),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '* Required fields',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: Colors.black.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          _sectionCard(
                            title: 'Personal information',
                            subtitle:
                                'These details are required before we continue with instructor onboarding.',
                            children: [
                              TextFormField(
                                controller: _firstNameController,
                                decoration: _fieldDecoration(
                                  label: 'First Name *',
                                ),
                                textCapitalization: TextCapitalization.words,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'First name is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _lastNameController,
                                decoration: _fieldDecoration(
                                  label: 'Last Name *',
                                ),
                                textCapitalization: TextCapitalization.words,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Last name is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                decoration: _fieldDecoration(
                                  label: 'Phone Number *',
                                  prefixText: '+1 ',
                                ),
                                validator: _validatePhone,
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Profile photo *',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _qText,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: Container(
                                  width: 132,
                                  height: 132,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _qBg,
                                    border: Border.all(color: _qBorder),
                                    image: _profileImagePath == null
                                        ? null
                                        : DecorationImage(
                                            image: FileImage(
                                              File(_profileImagePath!),
                                            ),
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                  child: _profileImagePath == null
                                      ? const Icon(
                                          Icons.person_rounded,
                                          size: 64,
                                          color: _qPrimary,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _pickProfileImage(ImageSource.camera),
                                    icon: const Icon(
                                      Icons.photo_camera_outlined,
                                    ),
                                    label: const Text('Take photo'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _pickProfileImage(ImageSource.gallery),
                                    icon: const Icon(
                                      Icons.photo_library_outlined,
                                    ),
                                    label: const Text('Choose photo'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _sectionCard(
                            title: 'Ontario G licence',
                            children: [
                              TextFormField(
                                controller: _licenceNumberController,
                                decoration: _fieldDecoration(
                                  label: 'Ontario G Licence Number *',
                                ),
                                textCapitalization:
                                    TextCapitalization.characters,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Licence number is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _licenceExpiryController,
                                readOnly: true,
                                decoration: _fieldDecoration(
                                  label: 'Licence Expiry *',
                                  suffixIcon: const Icon(Icons.calendar_today),
                                ),
                                onTap: _pickLicenceExpiry,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _sectionCard(
                            title: 'Vehicles',
                            subtitle:
                                'Add one or more vehicles you teach with.',
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _selectedVehicleType,
                                decoration:
                                    _fieldDecoration(label: 'Vehicle Type *'),
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
                                decoration:
                                    _fieldDecoration(label: 'Transmission *'),
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
                                    child: TextField(
                                      controller: _vehicleYearController,
                                      keyboardType: TextInputType.number,
                                      decoration: _fieldDecoration(
                                        label: 'Year *',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _vehicleMakeController,
                                      decoration: _fieldDecoration(
                                        label: 'Company / Make *',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _vehicleModelController,
                                decoration: _fieldDecoration(label: 'Model *'),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _vehiclePlateController,
                                decoration:
                                    _fieldDecoration(label: 'Number Plate *'),
                                textCapitalization:
                                    TextCapitalization.characters,
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _chooseVehicleImageSource,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _qPrimary,
                                      side: const BorderSide(color: _qPrimary),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    icon: const Icon(
                                        Icons.photo_camera_back_outlined),
                                    label: Text(
                                      _pendingVehicleImagePath == null
                                          ? 'Add vehicle photo'
                                          : 'Change vehicle photo',
                                    ),
                                  ),
                                  if (_pendingVehicleImagePath != null)
                                    IconButton(
                                      tooltip: 'Remove selected photo',
                                      onPressed: () => setState(
                                        () => _pendingVehicleImagePath = null,
                                      ),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                ],
                              ),
                              if (_pendingVehicleImagePath != null) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  height: 160,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
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
                                child: ElevatedButton.icon(
                                  onPressed: _handleAddVehicle,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _qPrimary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add vehicle'),
                                ),
                              ),
                              if (_vehicles.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Column(
                                  children: [
                                    for (final vehicle in _vehicles)
                                      Container(
                                        width: double.infinity,
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _qBg,
                                          border: Border.all(color: _qBorder),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildVehiclePhotoChip(vehicle),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${vehicle.type} - ${vehicle.year} ${vehicle.make} ${vehicle.model}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: _qText,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    'Plate: ${vehicle.numberPlate}',
                                                    style: TextStyle(
                                                      color: Colors.black
                                                          .withValues(
                                                        alpha: 0.6,
                                                      ),
                                                    ),
                                                  ),
                                                  if (vehicle
                                                      .transmission.isNotEmpty)
                                                    Text(
                                                      'Transmission: ${vehicle.transmission}',
                                                      style: TextStyle(
                                                        color: Colors.black
                                                            .withValues(
                                                          alpha: 0.6,
                                                        ),
                                                      ),
                                                    ),
                                                  if (vehicle.hasPhoto)
                                                    Text(
                                                      'Photo attached',
                                                      style: TextStyle(
                                                        color: Colors.black
                                                            .withValues(
                                                          alpha: 0.55,
                                                        ),
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
                            ],
                          ),
                          const SizedBox(height: 14),
                          _sectionCard(
                            title: 'Pickup preference',
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: _qBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _qBorder),
                                ),
                                child: SwitchListTile.adaptive(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  title: const Text(
                                    'Would you like to pick up learners from their location?',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: _qText,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _pickupPreference ? 'Yes' : 'No',
                                  ),
                                  value: _pickupPreference,
                                  activeThumbColor: _qPrimary,
                                  activeTrackColor:
                                      _qPrimary.withValues(alpha: 0.3),
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
                              ),
                              if (!_pickupPreference) ...[
                                const SizedBox(height: 12),
                                const Text(
                                  'Preferred lesson locations *',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: _qText,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildLocationOption(
                                  label: 'Home',
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
                                if (_homeSelected) ...[
                                  TextField(
                                    controller: _homeAddressController,
                                    decoration: _fieldDecoration(
                                      label: 'Home Address *',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                _buildLocationOption(
                                  label: 'Office',
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
                                if (_officeSelected) ...[
                                  TextField(
                                    controller: _officeAddressController,
                                    decoration: _fieldDecoration(
                                      label: 'Office Address *',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                _buildLocationOption(
                                  label: 'Other',
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
                                  TextField(
                                    controller: _otherLabelController,
                                    decoration: _fieldDecoration(
                                      label: 'Location Label *',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _otherAddressController,
                                    decoration: _fieldDecoration(
                                      label: 'Location Address *',
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),
                          _sectionCard(
                            title: 'Personal details',
                            children: [
                              TextFormField(
                                controller: _ageController,
                                keyboardType: TextInputType.number,
                                decoration: _fieldDecoration(label: 'Age *'),
                                validator: (value) {
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
                              const SizedBox(height: 14),
                              DropdownButtonFormField<String>(
                                initialValue: _gender,
                                decoration: _fieldDecoration(label: 'Gender *'),
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
                                onChanged: (value) =>
                                    setState(() => _gender = value),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a gender option';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _sectionCard(
                            title: 'Offerings & rates *',
                            subtitle:
                                'Select one or more offerings and set an hourly rate.',
                            children: [
                              Column(
                                children: _offeringOptions.map((option) {
                                  final isSelected =
                                      _selectedOfferings[option.code] ?? false;
                                  final rateController =
                                      _rateControllers[option.code]!;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _qBg,
                                      border: Border.all(color: _qBorder),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                          controlAffinity:
                                              ListTileControlAffinity.trailing,
                                          activeColor: _qPrimary,
                                          title: Text(
                                            option.label,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: _qText,
                                            ),
                                          ),
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
                                            padding:
                                                const EdgeInsets.only(top: 8),
                                            child: TextField(
                                              controller: rateController,
                                              keyboardType: const TextInputType
                                                  .numberWithOptions(
                                                decimal: true,
                                              ),
                                              decoration: _fieldDecoration(
                                                label: 'Hourly rate (\$) *',
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _handleContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _qPrimary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: const Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: Text(
                              'You can update these details later in profile settings.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black.withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
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
