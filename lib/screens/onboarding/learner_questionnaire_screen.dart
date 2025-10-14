import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';

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
  final _cityController = TextEditingController();
  final _ageController = TextEditingController();
  final _classesTakenController = TextEditingController();

  final _g1TestDateController = TextEditingController();
  final _g1ExpiryDateController = TextEditingController();
  final _lastClassDateController = TextEditingController();

  DateTime? _g1TestDate;
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

  @override
  void dispose() {
    _g1NumberController.dispose();
    _cityController.dispose();
    _ageController.dispose();
    _classesTakenController.dispose();
    _g1TestDateController.dispose();
    _g1ExpiryDateController.dispose();
    _lastClassDateController.dispose();
    _homeAddressController.dispose();
    _officeAddressController.dispose();
    _otherLabelController.dispose();
    _otherAddressController.dispose();
    super.dispose();
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

  void _handleContinue() {
    if (!_formKey.currentState!.validate()) return;
    if (_g1TestDate == null || _g1ExpiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both G1 test date and expiry date.'),
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

    final questionnaireData = <String, dynamic>{
      'city': _cityController.text.trim(),
      'age': age,
      'gender': _gender,
      'classesTaken': classesTaken,
      'lastClassDate': _lastClassDate?.toIso8601String(),
      'g1TestDate': _g1TestDate?.toIso8601String(),
      'locations': locations,
    };

    context.go(
      AppRoutes.licenseInfo,
      extra: {
        'role': widget.role,
        'initialLicenceNumber': _g1NumberController.text.trim(),
        'initialLicenceExpiry': _g1ExpiryDate?.toIso8601String(),
        'questionnaire': questionnaireData,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Please ensure all details match your G1 licence card.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'G1 Licence Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
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
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _g1TestDateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'G1 Test Date',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        onTap: () => _pickDate(
                          context: context,
                          controller: _g1TestDateController,
                          currentValue: _g1TestDate,
                          onSelected: (value) => setState(() {
                            _g1TestDate = value;
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
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
                    ),
                  ],
                ),
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
                  'Where do you prefer to start lessons?',
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
                  'Lesson History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue,
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
                      backgroundColor: AppColors.primaryBlue,
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
