import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../constants/ontario_locations.dart';
import '../../models/learner_onboarding_draft.dart';
import '../../widgets/app_circle_icon_button.dart';
import '../../widgets/app_primary_button.dart';

class LearnerQuestionnaireScreen extends StatefulWidget {
  const LearnerQuestionnaireScreen({
    super.key,
    this.initialDraft = const LearnerOnboardingDraft(),
  });

  final LearnerOnboardingDraft initialDraft;

  @override
  State<LearnerQuestionnaireScreen> createState() =>
      _LearnerQuestionnaireScreenState();
}

class _LearnerQuestionnaireScreenState
    extends State<LearnerQuestionnaireScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _wardFirstNameController;
  late final TextEditingController _wardLastNameController;
  late final TextEditingController _g1NumberController;
  late final TextEditingController _g1ExpiryController;
  late final TextEditingController _ageController;
  late final TextEditingController _classesTakenController;
  late final TextEditingController _lastClassController;

  DateTime? _g1ExpiryDate;
  DateTime? _lastClassDate;
  String? _selectedCity;
  String? _selectedGender;
  bool get _isGuardianAccount =>
      widget.initialDraft.learnerAccountType == 'guardian';

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    _firstNameController = TextEditingController(text: draft.firstName ?? '');
    _lastNameController = TextEditingController(text: draft.lastName ?? '');
    _phoneController = TextEditingController(text: draft.phone ?? '');
    _wardFirstNameController =
        TextEditingController(text: draft.wardFirstName ?? '');
    _wardLastNameController =
        TextEditingController(text: draft.wardLastName ?? '');
    _g1NumberController =
        TextEditingController(text: draft.g1LicenceNumber ?? '');
    _g1ExpiryDate = draft.g1ExpiryDate;
    _g1ExpiryController = TextEditingController(
      text: draft.g1ExpiryDate == null ? '' : _formatDate(draft.g1ExpiryDate!),
    );
    _ageController = TextEditingController(text: draft.age?.toString() ?? '');
    _classesTakenController = TextEditingController(
      text: draft.classesTakenSoFar?.toString() ?? '',
    );
    _lastClassDate = draft.lastClassDate;
    _lastClassController = TextEditingController(
      text:
          draft.lastClassDate == null ? '' : _formatDate(draft.lastClassDate!),
    );
    _selectedCity = draft.city;
    _selectedGender = draft.gender;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _wardFirstNameController.dispose();
    _wardLastNameController.dispose();
    _g1NumberController.dispose();
    _g1ExpiryController.dispose();
    _ageController.dispose();
    _classesTakenController.dispose();
    _lastClassController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required TextEditingController controller,
    required DateTime? currentValue,
    required DateTime firstDate,
    required DateTime lastDate,
    required ValueChanged<DateTime> onSelected,
  }) async {
    final fallbackDate = currentValue != null &&
            !currentValue.isBefore(firstDate) &&
            !currentValue.isAfter(lastDate)
        ? currentValue
        : lastDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: fallbackDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked == null) return;
    onSelected(picked);
    controller.text = _formatDate(picked);
  }

  String _formatDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  String? _validatePhone(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Enter your phone number';
    }
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 10) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;

    if (_g1ExpiryDate == null) {
      _showError('Please select your licence expiry date.');
      return;
    }

    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedExpiry = DateTime(
      _g1ExpiryDate!.year,
      _g1ExpiryDate!.month,
      _g1ExpiryDate!.day,
    );
    if (normalizedExpiry.isBefore(normalizedToday)) {
      _showError('Your licence expiry date must be today or later.');
      return;
    }

    if (_selectedCity == null || _selectedCity!.trim().isEmpty) {
      _showError('Please select your city.');
      return;
    }

    if (_selectedGender == null || _selectedGender!.trim().isEmpty) {
      _showError('Please select your gender.');
      return;
    }

    final age = int.tryParse(_ageController.text.trim());
    if (age == null) {
      _showError('Enter a valid age.');
      return;
    }
    if (_isGuardianAccount) {
      if (age < 16) {
        _showError('Ward learners must be at least 16 years old to continue.');
        return;
      }
    } else if (age < 18) {
      _showError(
        'Learners under 18 need a guardian to create and manage the account.',
      );
      return;
    }
    if (age > 100) {
      _showError('Enter a valid age.');
      return;
    }

    final classesTakenText = _classesTakenController.text.trim();
    final classesTaken =
        classesTakenText.isEmpty ? null : int.tryParse(classesTakenText);
    if (classesTakenText.isNotEmpty && classesTaken == null) {
      _showError('Enter a valid number of completed lessons.');
      return;
    }

    final draft = widget.initialDraft.copyWith(
      role: widget.initialDraft.role,
      learnerAccountType: widget.initialDraft.learnerAccountType,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: _phoneController.text.trim(),
      wardFirstName:
          _isGuardianAccount ? _wardFirstNameController.text.trim() : null,
      wardLastName:
          _isGuardianAccount ? _wardLastNameController.text.trim() : null,
      g1LicenceNumber: _g1NumberController.text.trim().toUpperCase(),
      g1ExpiryDate: _g1ExpiryDate,
      city: _selectedCity!.trim(),
      age: age,
      gender: _selectedGender!.trim(),
      classesTakenSoFar: classesTaken,
      lastClassDate: _lastClassDate,
    );

    context.go(AppRoutes.learnerPickupAddress, extra: draft);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    Widget? suffixIcon,
  }) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
      borderSide: BorderSide(color: AppColors.border),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: AppColors.mutedForeground,
        fontSize: 15,
      ),
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: border,
      enabledBorder: border,
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A111827),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.foreground,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
          const SizedBox(height: 18),
          ...children,
        ],
      ),
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
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppCircleIconButton(
                            icon: Icons.arrow_back_rounded,
                            size: 56,
                            onPressed: () =>
                                context.go(AppRoutes.learnerApprovalSuccess),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: 1 / 3,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      Text(
                        _isGuardianAccount
                            ? 'Guardian and learner details'
                            : 'Tell us about you',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isGuardianAccount
                            ? "We'll use your guardian account for notifications and your ward's details for lessons."
                            : 'We need a few learner details before we set your pickup and weekly schedule.',
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.45,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _sectionCard(
                        title: _isGuardianAccount
                            ? 'Guardian information'
                            : 'Personal information',
                        subtitle: _isGuardianAccount
                            ? 'This account belongs to the guardian responsible for the learner.'
                            : 'These details are required before you can continue.',
                        children: [
                          TextFormField(
                            controller: _firstNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: _fieldDecoration(label: 'First name'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter your first name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _lastNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: _fieldDecoration(label: 'Last name'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter your last name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: _fieldDecoration(label: 'Phone number'),
                            validator: _validatePhone,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_isGuardianAccount) ...[
                        _sectionCard(
                          title: 'Ward information',
                          subtitle:
                              'Instructors will see that this is a guardian-managed learner request.',
                          children: [
                            TextFormField(
                              controller: _wardFirstNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: _fieldDecoration(
                                label: 'Ward first name',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Enter the learner's first name";
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _wardLastNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: _fieldDecoration(
                                label: 'Ward last name',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return "Enter the learner's last name";
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                      _sectionCard(
                        title: 'G1/G2/G Licence',
                        subtitle: _isGuardianAccount
                            ? "Enter the ward learner's licence details."
                            : 'Enter the learner licence details you will use for lessons.',
                        children: [
                          TextFormField(
                            controller: _g1NumberController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: _fieldDecoration(
                              label: _isGuardianAccount
                                  ? 'Ward G1/G2/G licence number'
                                  : 'G1/G2/G licence number',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return _isGuardianAccount
                                    ? "Enter the ward learner's licence number"
                                    : 'Enter your G1 licence number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _g1ExpiryController,
                            readOnly: true,
                            decoration: _fieldDecoration(
                              label: _isGuardianAccount
                                  ? 'Ward G1/G2/G expiry date'
                                  : 'G1/G2/G expiry date',
                              suffixIcon: IconButton(
                                onPressed: () => _pickDate(
                                  controller: _g1ExpiryController,
                                  currentValue: _g1ExpiryDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(DateTime.now().year + 10),
                                  onSelected: (value) =>
                                      setState(() => _g1ExpiryDate = value),
                                ),
                                icon: const Icon(Icons.calendar_today_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _sectionCard(
                        title: _isGuardianAccount
                            ? 'Ward learner details'
                            : 'Basic details',
                        subtitle: _isGuardianAccount
                            ? 'This helps match your ward with the right instructors and lesson options.'
                            : 'This helps match you with the right instructors and lesson options.',
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCity,
                            decoration: _fieldDecoration(label: 'City'),
                            items: cityOptions
                                .map(
                                  (city) => DropdownMenuItem<String>(
                                    value: city,
                                    child: Text(city),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _selectedCity = value),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Select your city'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            decoration: _fieldDecoration(
                              label: _isGuardianAccount ? 'Ward age' : 'Age',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return _isGuardianAccount
                                    ? "Enter the ward learner's age"
                                    : 'Enter your age';
                              }
                              if (int.tryParse(value.trim()) == null) {
                                return 'Enter a valid age';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedGender,
                            decoration: _fieldDecoration(label: 'Gender'),
                            items: const [
                              DropdownMenuItem(
                                value: 'Male',
                                child: Text('Male'),
                              ),
                              DropdownMenuItem(
                                value: 'Female',
                                child: Text('Female'),
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
                                setState(() => _selectedGender = value),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Select your gender'
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _sectionCard(
                        title: _isGuardianAccount
                            ? "Ward's lesson history"
                            : 'Lesson history',
                        subtitle:
                            'Keep this accurate so the app can reflect your current progress.',
                        children: [
                          TextFormField(
                            controller: _classesTakenController,
                            keyboardType: TextInputType.number,
                            decoration: _fieldDecoration(
                              label: 'Lessons completed so far',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _lastClassController,
                            readOnly: true,
                            decoration: _fieldDecoration(
                              label: 'Last class date',
                              suffixIcon: IconButton(
                                onPressed: () => _pickDate(
                                  controller: _lastClassController,
                                  currentValue: _lastClassDate,
                                  firstDate: DateTime(1970),
                                  lastDate: DateTime.now(),
                                  onSelected: (value) =>
                                      setState(() => _lastClassDate = value),
                                ),
                                icon: const Icon(Icons.calendar_today_rounded),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: AppPrimaryButton(
                  label: 'Continue',
                  onPressed: _handleContinue,
                  height: 64,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
