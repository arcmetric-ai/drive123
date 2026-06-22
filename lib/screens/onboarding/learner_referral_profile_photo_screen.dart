import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../services/instructor_referral_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_circle_icon_button.dart';
import '../../widgets/app_primary_button.dart';

class LearnerReferralProfilePhotoScreen extends StatefulWidget {
  const LearnerReferralProfilePhotoScreen({
    super.key,
    this.nextRoute,
    this.nextExtra,
  });

  final String? nextRoute;
  final Object? nextExtra;

  @override
  State<LearnerReferralProfilePhotoScreen> createState() =>
      _LearnerReferralProfilePhotoScreenState();
}

class _LearnerReferralProfilePhotoScreenState
    extends State<LearnerReferralProfilePhotoScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;
  bool _isSaving = false;

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked == null || !mounted) return;
      setState(() => _selectedImage = picked);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to choose photo: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _continue() async {
    final selectedImage = _selectedImage;
    if (selectedImage == null || _isSaving) return;

    setState(() => _isSaving = true);
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('Please sign in again to continue.');
      }

      await SupabaseService.uploadProfileImage(
        userId: userId,
        file: File(selectedImage.path),
      );

      await InstructorReferralService.claimPendingCodeIfAvailable();

      if (!mounted) return;
      context.go(
        widget.nextRoute ?? AppRoutes.home,
        extra: widget.nextExtra,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to connect instructor: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _selectedImage;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      size: 56,
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(height: 36),
                    const Text(
                      'Add your profile photo',
                      style: TextStyle(
                        fontSize: 38,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                        color: AppColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Learners and instructors need a clear profile photo before using Drive Tutor. Instructors will see this photo when reviewing lesson requests.',
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.45,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Center(
                      child: Container(
                        width: 188,
                        height: 188,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.dreamy,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.18),
                            width: 2,
                          ),
                          image: photo == null
                              ? null
                              : DecorationImage(
                                  image: FileImage(File(photo.path)),
                                  fit: BoxFit.cover,
                                ),
                        ),
                        child: photo == null
                            ? Icon(
                                Icons.person_rounded,
                                size: 86,
                                color: AppColors.primary.withValues(
                                  alpha: 0.42,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 36),
                    _PhotoActionButton(
                      icon: Icons.photo_camera_rounded,
                      label: 'Take Photo',
                      onPressed: () => _pickPhoto(ImageSource.camera),
                    ),
                    const SizedBox(height: 14),
                    _PhotoActionButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Choose From Library',
                      onPressed: () => _pickPhoto(ImageSource.gallery),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: AppPrimaryButton(
                label: 'Continue',
                onPressed: photo == null || _isSaving ? null : _continue,
                isLoading: _isSaving,
                height: 64,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoActionButton extends StatelessWidget {
  const _PhotoActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.24)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    );
  }
}
