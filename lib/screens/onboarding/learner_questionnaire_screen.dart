import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../constants/ontario_locations.dart';
import '../../models/learner_onboarding_draft.dart';
import '../../services/supabase_service.dart';
import '../../utils/ontario_phone_number.dart';
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
  bool _isCheckingPhone = false;
  bool get _isGuardianAccount =>
      widget.initialDraft.learnerAccountType == 'guardian';

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft;
    _firstNameController = TextEditingController(text: draft.firstName ?? '');
    _lastNameController = TextEditingController(text: draft.lastName ?? '');
    _phoneController = TextEditingController(
      text: OntarioPhoneNumber.displayLocal(draft.phone),
    );
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
    bool preferLatestInitial = false,
  }) async {
    final normalizedFirst = DateTime(
      firstDate.year,
      firstDate.month,
      firstDate.day,
    );
    final normalizedLast = DateTime(
      lastDate.year,
      lastDate.month,
      lastDate.day,
    );
    final fallbackDate = currentValue != null &&
            !currentValue.isBefore(normalizedFirst) &&
            !currentValue.isAfter(normalizedLast)
        ? currentValue
        : preferLatestInitial
            ? normalizedLast
            : normalizedFirst;
    final picked = await showDatePicker(
      context: context,
      initialDate: fallbackDate,
      firstDate: normalizedFirst,
      lastDate: normalizedLast,
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
    if (!OntarioPhoneNumber.isValid(trimmed)) {
      return 'Enter a valid 10-digit Ontario phone number';
    }
    return null;
  }

  Future<void> _handleContinue() async {
    if (!_formKey.currentState!.validate()) return;

    if (_g1ExpiryDate == null) {
      _showError('Please select your licence expiry date.');
      return;
    }

    final normalizedToday = _today;
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
    } else if (age == 16 || age == 17) {
      final guardianDraft = LearnerOnboardingDraft(
        role: widget.initialDraft.role,
        learnerAccountType: 'guardian',
        wardFirstName: _firstNameController.text.trim(),
        wardLastName: _lastNameController.text.trim(),
        g1LicenceNumber: _g1NumberController.text.trim().toUpperCase(),
        g1ExpiryDate: _g1ExpiryDate,
        city: _selectedCity?.trim(),
        age: age,
        gender: _selectedGender?.trim(),
        classesTakenSoFar: int.tryParse(_classesTakenController.text.trim()),
        lastClassDate: _lastClassDate,
      );
      _showError(
        'You are $age years old and require a guardian account instead of a learner account.',
      );
      context.go(AppRoutes.learnerQuestionnaire, extra: guardianDraft);
      return;
    } else if (age < 18) {
      _showError(
        'Learners must be at least 16 years old to use Drive Tutor.',
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
    if (classesTaken != null && classesTaken < 0) {
      _showError('Completed lessons cannot be negative.');
      return;
    }
    if (_lastClassDate != null && _lastClassDate!.isAfter(normalizedToday)) {
      _showError('Most recent class date cannot be in the future.');
      return;
    }

    final phone = OntarioPhoneNumber.toE164(_phoneController.text);
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      _showError('Please sign in again to continue.');
      return;
    }

    setState(() => _isCheckingPhone = true);
    try {
      await SupabaseService.ensurePhoneNumberAvailableForUser(
        phone,
        userId: userId,
      );
    } on PhoneNumberInUseException {
      _showError(
        'That phone number is already attached to an account. Use a different phone number or sign in to the existing account.',
      );
      return;
    } catch (_) {
      _showError('Unable to verify this phone number. Please try again.');
      return;
    } finally {
      if (mounted) {
        setState(() => _isCheckingPhone = false);
      }
    }
    if (!mounted) return;

    final draft = widget.initialDraft.copyWith(
      role: widget.initialDraft.role,
      learnerAccountType: widget.initialDraft.learnerAccountType,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: phone,
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
    String? prefixText,
  }) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
      borderSide: BorderSide(color: AppColors.border),
    );
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
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
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppCircleIconButton(
                            icon: Icons.arrow_back_rounded,
                            size: 48,
                            onPressed: () => context.go(AppRoutes.accountEntry),
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
                      const SizedBox(height: 18),
                      Text(
                        _isGuardianAccount
                            ? 'Guardian account setup'
                            : 'Tell us about you',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isGuardianAccount
                            ? "Start with the guardian's contact details, then add the learner's licence, lesson history, pickup spots, and availability."
                            : 'We need a few learner details before we set your pickup and weekly schedule.',
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _sectionCard(
                        title: _isGuardianAccount
                            ? 'Guardian information'
                            : 'Personal information',
                        subtitle: _isGuardianAccount
                            ? "Enter the parent or legal guardian's details here. This person receives account updates and manages the learner."
                            : 'These details are required before you can continue.',
                        children: [
                          TextFormField(
                            controller: _firstNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: _fieldDecoration(
                              label: _isGuardianAccount
                                  ? 'Guardian first name'
                                  : 'First name',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return _isGuardianAccount
                                    ? "Enter the guardian's first name"
                                    : 'Enter your first name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _lastNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: _fieldDecoration(
                              label: _isGuardianAccount
                                  ? 'Guardian last name'
                                  : 'Last name',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return _isGuardianAccount
                                    ? "Enter the guardian's last name"
                                    : 'Enter your last name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: _fieldDecoration(
                              label: _isGuardianAccount
                                  ? 'Guardian phone number'
                                  : 'Phone number',
                              prefixText: '+1 ',
                            ),
                            validator: _validatePhone,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_isGuardianAccount) ...[
                        _sectionCard(
                          title: 'Learner information',
                          subtitle:
                              'These fields are for the learner, not the guardian. Instructors will see this learner information.',
                          children: [
                            TextFormField(
                              controller: _wardFirstNameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: _fieldDecoration(
                                label: 'Learner first name',
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
                                label: 'Learner last name',
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
                        title: _isGuardianAccount
                            ? 'Learner G1/G2/G licence'
                            : 'G1/G2/G Licence',
                        subtitle: _isGuardianAccount
                            ? "Enter the learner's Ontario G1, G2, or G licence. The guardian government ID is uploaded later for verification."
                            : 'Enter the learner licence details you will use for lessons.',
                        children: [
                          TextFormField(
                            controller: _g1NumberController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: _fieldDecoration(
                              label: _isGuardianAccount
                                  ? 'Learner G1/G2/G licence number'
                                  : 'G1/G2/G licence number',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return _isGuardianAccount
                                    ? "Enter the learner's licence number"
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
                                  ? 'Learner G1/G2/G expiry date'
                                  : 'G1/G2/G expiry date',
                              suffixIcon: IconButton(
                                onPressed: () => _pickDate(
                                  controller: _g1ExpiryController,
                                  currentValue: _g1ExpiryDate,
                                  firstDate: _today,
                                  lastDate: DateTime(_today.year + 10),
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
                            ? 'Learner lesson details'
                            : 'Basic details',
                        subtitle: _isGuardianAccount
                            ? "Use the learner's city, age, and gender. These are not guardian details."
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
                                ? _isGuardianAccount
                                    ? "Select the learner's city"
                                    : 'Select your city'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            decoration: _fieldDecoration(
                              label: _isGuardianAccount ? 'Learner age' : 'Age',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return _isGuardianAccount
                                    ? "Enter the learner's age"
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
                            decoration: _fieldDecoration(
                              label: _isGuardianAccount
                                  ? 'Learner gender'
                                  : 'Gender',
                            ),
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
                                ? _isGuardianAccount
                                    ? "Select the learner's gender"
                                    : 'Select your gender'
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _sectionCard(
                        title: _isGuardianAccount
                            ? 'Learner lesson history'
                            : 'Lesson history',
                        subtitle: _isGuardianAccount
                            ? 'Tell us how many lessons the learner has already completed so instructors can start at the right level.'
                            : 'Keep this accurate so the app can reflect your current progress.',
                        children: [
                          TextFormField(
                            controller: _classesTakenController,
                            keyboardType: TextInputType.number,
                            decoration: _fieldDecoration(
                              label: _isGuardianAccount
                                  ? 'Learner lessons completed so far'
                                  : 'Lessons completed so far',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _lastClassController,
                            readOnly: true,
                            decoration: _fieldDecoration(
                              label: _isGuardianAccount
                                  ? "Learner's last class date"
                                  : 'Last class date',
                              suffixIcon: IconButton(
                                onPressed: () => _pickDate(
                                  controller: _lastClassController,
                                  currentValue: _lastClassDate,
                                  firstDate: DateTime(1970),
                                  lastDate: _today,
                                  preferLatestInitial: true,
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: AppPrimaryButton(
                  label: 'Continue',
                  onPressed: _isCheckingPhone ? null : _handleContinue,
                  isLoading: _isCheckingPhone,
                  height: 56,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
