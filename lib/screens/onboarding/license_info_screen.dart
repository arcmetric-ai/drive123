import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../services/supabase_service.dart';

class LicenseInfoScreen extends StatefulWidget {
  final String role;

  const LicenseInfoScreen({
    super.key,
    required this.role,
  });

  @override
  State<LicenseInfoScreen> createState() => _LicenseInfoScreenState();
}

class _LicenseInfoScreenState extends State<LicenseInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _expiryController = TextEditingController();
  DateTime? _selectedExpiryDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _numberController.dispose();
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

    final licenceNumber = _numberController.text.trim();
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
      if (widget.role == 'instructor') {
        await SupabaseService.upsertInstructorProfile(
          userId: userId,
          licenceNumber: licenceNumber,
          licenceExpiry: expiryDate,
        );
      } else {
        await SupabaseService.upsertLearnerProfile(
          userId: userId,
          licenceNumber: licenceNumber,
          licenceExpiry: expiryDate,
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
              : 'Instructor credentials saved. Welcome to Drive T!',
        ),
        backgroundColor: AppColors.success,
      ),
    );

    setState(() => _isSubmitting = false);

    if (widget.role == 'learner') {
      context.go(AppRoutes.learningFocus, extra: widget.role);
    } else {
      context.go(AppRoutes.instructorHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLearner = widget.role == 'learner';
    final title = isLearner ? 'Learner Details' : 'Instructor Credentials';
    final subtitle = isLearner
        ? 'Add your G1 license information to continue'
        : 'Add your instructor license details to continue';
    final numberLabel = isLearner ? 'G1 License Number' : 'Instructor License Number';
    final buttonColor =
        isLearner ? AppColors.primaryBlue : AppColors.accentYellow;

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
                          color: isLearner
                              ? AppColors.primaryBlue
                              : AppColors.accentYellow,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          isLearner ? Icons.assignment : Icons.badge,
                          color: isLearner ? Colors.white : AppColors.primaryBlue,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
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
                TextFormField(
                  controller: _numberController,
                  decoration: InputDecoration(
                    labelText: numberLabel,
                    prefixIcon: const Icon(Icons.numbers),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primaryBlue,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a license number';
                    }
                    return null;
                  },
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
                            color: AppColors.primaryBlue,
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
