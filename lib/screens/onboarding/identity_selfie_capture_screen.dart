import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../widgets/guided_capture_frame.dart';
import '../../widgets/identity_capture_scene.dart';

class IdentitySelfieCaptureScreen extends StatefulWidget {
  const IdentitySelfieCaptureScreen({
    super.key,
    required this.role,
    this.licenseImagePath,
    this.selfieImagePath,
  });

  final String role;
  final String? licenseImagePath;
  final String? selfieImagePath;

  @override
  State<IdentitySelfieCaptureScreen> createState() =>
      _IdentitySelfieCaptureScreenState();
}

class _IdentitySelfieCaptureScreenState
    extends State<IdentitySelfieCaptureScreen> {
  static const _testingBypassEnabled = true;
  final _imagePicker = ImagePicker();
  String? _imagePath;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.selfieImagePath;
  }

  Future<XFile?> _pickSelfie(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
      preferredCameraDevice:
          source == ImageSource.camera ? CameraDevice.front : CameraDevice.rear,
    );
    return picked;
  }

  Future<void> _captureSelfie() async {
    if (_isSubmitting) return;

    XFile? picked;
    try {
      picked = await _pickSelfie(ImageSource.camera);
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
        picked = await _pickSelfie(ImageSource.gallery);
      } catch (galleryError) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to select selfie image: $galleryError'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    final pickedFile = picked;
    if (pickedFile == null || !mounted) return;

    setState(() => _imagePath = pickedFile.path);

    final licenseImagePath = widget.licenseImagePath;
    final user = SupabaseService.currentUser;

    if (licenseImagePath == null || user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to submit verification. Please try again.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await SupabaseService.submitIdentityVerification(
        userId: user.id,
        role: widget.role,
        licenseImagePath: licenseImagePath,
        selfieImagePath: pickedFile.path,
      );
      if (!mounted) return;
      context.go(
        widget.role == 'instructor'
            ? AppRoutes.instructorQuestionnaire
            : AppRoutes.identityPendingReview,
        extra: {'role': widget.role},
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to upload verification: $error'),
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _skipForTesting() async {
    if (_isSubmitting) return;

    final user = SupabaseService.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in again to continue testing.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await SupabaseService.approveIdentityVerificationForTesting(
        userId: user.id,
        role: widget.role,
      );
      if (!mounted) return;
      final state = await SupabaseService.getCurrentIdentityVerificationState();
      if (!mounted) return;
      context.go(
        widget.role == 'instructor'
            ? AppRoutes.instructorQuestionnaire
            : state?.onboardingStage ==
                    SupabaseService.onboardingStageQuestionnaireComplete
                ? AppRoutes.home
                : AppRoutes.learnerQuestionnaire,
        extra: {'role': widget.role},
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to bypass verification: $error'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IdentityCaptureScene(
      stepLabel: 'Step 3 of 4',
      title: 'Position your face within the oval',
      imagePath: _imagePath,
      shape: CaptureFrameShape.oval,
      onClose: () => context.pop(),
      onAction: _captureSelfie,
      onCapture: _captureSelfie,
      isBusy: _isSubmitting,
      secondaryActionLabel: _testingBypassEnabled ? 'Skip for testing' : null,
      onSecondaryAction: _testingBypassEnabled ? _skipForTesting : null,
    );
  }
}
