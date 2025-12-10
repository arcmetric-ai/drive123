import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../constants/ontario_locations.dart';
import '../../services/supabase_service.dart';

class LearnerQuestionnaireScreen extends StatefulWidget {
  final String role;

  const LearnerQuestionnaireScreen({
    super.key,
    required this.role,
  });

  @override
  State<LearnerQuestionnaireScreen> createState() =>
      _LearnerQuestionnaireScreenState();
}

class _LearnerQuestionnaireScreenState
    extends State<LearnerQuestionnaireScreen> {
  final _formKey = GlobalKey<FormState>();

  final _g1NumberController = TextEditingController();
  final _ageController = TextEditingController();
  final _classesTakenController = TextEditingController();
  final _g1ExpiryDateController = TextEditingController();
  final _lastClassDateController = TextEditingController();

  String? _selectedCity;
  DateTime? _g1ExpiryDate;
  DateTime? _lastClassDate;
  String? _gender;
  final _homeAddressController = TextEditingController();
  final _officeAddressController = TextEditingController();
  final _otherLabelController = TextEditingController();
  final _otherAddressController = TextEditingController();
  bool _homeSelected = false;
  bool _officeSelected = false;
  bool _otherSelected = false;
  static const List<String> _weekDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const List<Map<String, String>> _timeSlotDefinitions = [
    {'key': 'early', 'label': 'Early (7am-9am)'},
    {'key': 'morning', 'label': 'Morning (9am-12pm)'},
    {'key': 'afternoon', 'label': 'Afternoon (12pm-4pm)'},
    {'key': 'evening', 'label': 'Evening (4pm-8pm)'},
  ];
  static const Map<String, int> _slotOrder = {
    'early': 0,
    'morning': 1,
    'afternoon': 2,
    'evening': 3,
  };
  final Map<String, Set<String>> _weeklyAvailability = {
    for (final day in _weekDays) day.toLowerCase(): <String>{},
  };
  bool _availabilityRecurring = false;

  @override
  void dispose() {
    _g1NumberController.dispose();
    _ageController.dispose();
    _classesTakenController.dispose();
    _g1ExpiryDateController.dispose();
    _lastClassDateController.dispose();
    _homeAddressController.dispose();
    _officeAddressController.dispose();
    _otherLabelController.dispose();
    _otherAddressController.dispose();
    super.dispose();
  }

  void _toggleAvailability(String dayKey, String slotKey, bool isSelected) {
    final slots = _weeklyAvailability[dayKey];
    if (slots == null) return;
    setState(() {
      if (isSelected) {
        slots.add(slotKey);
      } else {
        slots.remove(slotKey);
      }
    });
  }

  void _clearAvailabilityForDay(String dayKey) {
    final slots = _weeklyAvailability[dayKey];
    if (slots == null || slots.isEmpty) return;
    setState(() {
      slots.clear();
    });
  }

  Future<void> _pickDate({
    required BuildContext context,
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
      controller.text = _formatDate(picked);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;
    if (_g1ExpiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your G1 expiry date.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final classesTaken = int.tryParse(_classesTakenController.text.trim());
    final age = int.tryParse(_ageController.text.trim());

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

    if (_selectedCity == null || _selectedCity!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your city.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final availabilityPayload = _weeklyAvailability.entries
        .map((entry) {
          final slots = List<String>.from(entry.value);
          slots.sort(
              (a, b) => (_slotOrder[a] ?? 0).compareTo(_slotOrder[b] ?? 0));
          return {
            'day': entry.key,
            'slots': slots,
          };
        })
        .where((entry) => (entry['slots'] as List).isNotEmpty)
        .toList();

    if (availabilityPayload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one availability slot for the week.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final profileData = <String, dynamic>{};
    if (_selectedCity != null && _selectedCity!.trim().isNotEmpty) {
      profileData['city'] = _selectedCity!.trim();
    }
    if (age != null) {
      profileData['age'] = age;
    }
    if (_gender != null && _gender!.trim().isNotEmpty) {
      profileData['gender'] = _gender!.trim();
    }

    final learnerProfileData = <String, dynamic>{
      'preferred_locations':
          locations.map((entry) => Map<String, dynamic>.from(entry)).toList(),
      'weekly_availability': availabilityPayload,
      'availability_recurring': _availabilityRecurring,
    };
    if (classesTaken != null) {
      learnerProfileData['classes_taken_sofar'] = classesTaken;
    }
    if (_lastClassDate != null) {
      learnerProfileData['last_class_date'] = _lastClassDate!.toIso8601String();
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _persistLearnerQuestionnaire(
        profileData: profileData,
        learnerProfileData: learnerProfileData,
        licenceNumber: _g1NumberController.text.trim(),
        licenceExpiry: _g1ExpiryDate,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      context.go(AppRoutes.home);
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save your details: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _persistLearnerQuestionnaire({
    required Map<String, dynamic> profileData,
    required Map<String, dynamic> learnerProfileData,
    required String licenceNumber,
    required DateTime? licenceExpiry,
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      throw Exception('Please sign in again to continue.');
    }

    final updates = Map<String, dynamic>.from(profileData);
    final normalizedLicence = licenceNumber.trim().toUpperCase();
    if (normalizedLicence.isNotEmpty) {
      updates['licence_number'] = normalizedLicence;
    }
    if (licenceExpiry != null) {
      updates['licence_expiry'] = _formatDate(licenceExpiry);
    }

    await SupabaseService.updateProfileFields(userId, updates);

    List<Map<String, dynamic>>? _mapList(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry as Map))
            .toList();
      }
      return null;
    }

    int? _intOrNull(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    bool? _boolOrNull(dynamic value) {
      if (value is bool) return value;
      if (value is String) {
        final lowered = value.toLowerCase();
        if (lowered == 'true') return true;
        if (lowered == 'false') return false;
      }
      return null;
    }

    DateTime? _dateOrNull(dynamic value) {
      if (value is DateTime) return value;
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final learnerData = Map<String, dynamic>.from(learnerProfileData);

    await SupabaseService.upsertLearnerProfile(
      userId: userId,
      learningFocus: (learnerData['learning_focus'] as String?)?.trim(),
      targetTestDate: _dateOrNull(learnerData['target_test_date']),
      targetTestCentre: (learnerData['target_test_centre'] as String?)?.trim(),
      notes: (learnerData['notes'] as String?)?.trim(),
      classesTakenSoFar: _intOrNull(learnerData['classes_taken_sofar']),
      lastClassDate: _dateOrNull(learnerData['last_class_date']),
      preferredLocations: _mapList(learnerData['preferred_locations']),
      preferredLocationNotes:
          (learnerData['preferred_location_notes'] as String?)?.trim(),
      weeklyAvailability: _mapList(learnerData['weekly_availability']),
      availabilityRecurring: _boolOrNull(learnerData['availability_recurring']),
    );
  }

  Widget _buildAvailabilitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Weekly Availability',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.ocean,
          ),
        ),
        const SizedBox(height: 12),
        ..._weekDays.map((day) {
          final dayKey = day.toLowerCase();
          final selected = _weeklyAvailability[dayKey]!;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      day,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (selected.isNotEmpty)
                      TextButton(
                        onPressed: () => _clearAvailabilityForDay(dayKey),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                ..._timeSlotDefinitions.map((slot) {
                  final slotKey = slot['key']!;
                  final slotLabel = slot['label']!;
                  final isSelected = selected.contains(slotKey);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) =>
                        _toggleAvailability(dayKey, slotKey, value ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(slotLabel),
                  );
                }),
              ],
            ),
          );
        }),
        CheckboxListTile(
          value: _availabilityRecurring,
          onChanged: (value) =>
              setState(() => _availabilityRecurring = value ?? false),
          title: const Text('Make this availability recurring for the month'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cityOptions = List<String>.from(OntarioLocations.allCities);
    if (_selectedCity != null &&
        _selectedCity!.isNotEmpty &&
        !cityOptions.contains(_selectedCity)) {
      cityOptions.insert(0, _selectedCity!);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learner Questionnaire'),
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
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: AppColors.ocean.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Please ensure all details match your G1 licence card.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ocean,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'G1 Licence Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ocean,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _g1NumberController,
                  decoration: const InputDecoration(
                    labelText: 'G1 Licence Number',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'G1 licence number is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _g1ExpiryDateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'G1 Expiry Date',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () => _pickDate(
                    context: context,
                    controller: _g1ExpiryDateController,
                    currentValue: _g1ExpiryDate,
                    onSelected: (value) => setState(() {
                      _g1ExpiryDate = value;
                    }),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Personal Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ocean,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedCity,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: cityOptions
                      .map(
                        (city) => DropdownMenuItem(
                          value: city,
                          child: Text(
                            OntarioLocations.areaForCity(city) != null
                                ? '$city (${OntarioLocations.areaForCity(city)})'
                                : city,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _selectedCity = value),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'City is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
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
                  isExpanded: true,
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
                  'Where do you prefer to start lessons?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ocean,
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
                _buildAvailabilitySection(),
                const SizedBox(height: 24),
                const Text(
                  'Lesson History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ocean,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _classesTakenController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Number of classes taken so far',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please share how many classes you have taken';
                    }
                    final parsed = int.tryParse(value.trim());
                    if (parsed == null || parsed < 0) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastClassDateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'When was your most recent class?',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () => _pickDate(
                    context: context,
                    controller: _lastClassDateController,
                    currentValue: _lastClassDate,
                    onSelected: (value) => setState(() {
                      _lastClassDate = value;
                    }),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ocean,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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
