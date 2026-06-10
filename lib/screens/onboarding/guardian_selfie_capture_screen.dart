import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../widgets/guided_capture_frame.dart';
import '../../widgets/identity_capture_scene.dart';

class GuardianSelfieCaptureScreen extends StatefulWidget {
  const GuardianSelfieCaptureScreen({
    super.key,
    required this.role,
    required this.licenseImagePath,
    required this.selfieImagePath,
    required this.guardianLicenseImagePath,
    this.guardianSelfieImagePath,
  });

  final String role;
  final String licenseImagePath;
  final String selfieImagePath;
  final String guardianLicenseImagePath;
  final String? guardianSelfieImagePath;

  @override
  State<GuardianSelfieCaptureScreen> createState() =>
      _GuardianSelfieCaptureScreenState();
}

class _GuardianSelfieCaptureScreenState
    extends State<GuardianSelfieCaptureScreen> {
  final _imagePicker = ImagePicker();
  String? _imagePath;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.guardianSelfieImagePath;
  }

  Future<XFile?> _pickGuardianSelfie(ImageSource source) {
    return _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      preferredCameraDevice:
          source == ImageSource.camera ? CameraDevice.front : CameraDevice.rear,
    );
  }

  Future<void> _captureGuardianSelfie() async {
    if (_isSubmitting) return;

    XFile? picked;
    try {
      picked = await _pickGuardianSelfie(ImageSource.camera);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Camera is unavailable here. Opening photo library instead.',
          ),
          backgroundColor: AppColors.foreground,
        ),
      );
      try {
        picked = await _pickGuardianSelfie(ImageSource.gallery);
      } catch (galleryError) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to select guardian selfie: $galleryError'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    final pickedFile = picked;
    final user = SupabaseService.currentUser;
    if (pickedFile == null || user == null || !mounted) return;

    setState(() {
      _imagePath = pickedFile.path;
      _isSubmitting = true;
    });

    try {
      await SupabaseService.submitIdentityVerification(
        userId: user.id,
        role: widget.role,
        licenseImagePath: widget.licenseImagePath,
        selfieImagePath: widget.selfieImagePath,
        guardianLicenseImagePath: widget.guardianLicenseImagePath,
        guardianSelfieImagePath: pickedFile.path,
      );
      if (!mounted) return;
      context.go(
        AppRoutes.identityPendingReview,
        extra: {'role': widget.role},
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to upload guardian consent: $error'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IdentityCaptureScene(
      stepLabel: 'Guardian Step 2 of 2',
      title: 'Guardian face within the oval',
      imagePath: _imagePath,
      shape: CaptureFrameShape.oval,
      onClose: () => context.pop(),
      onAction: _captureGuardianSelfie,
      onCapture: _captureGuardianSelfie,
      isBusy: _isSubmitting,
    );
  }
}
