import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../widgets/guided_capture_frame.dart';
import '../../widgets/identity_capture_scene.dart';
import '../../widgets/in_app_camera_capture_screen.dart';

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
  String? _imagePath;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.selfieImagePath;
  }

  Future<void> _captureSelfie() async {
    if (_isSubmitting) return;

    final imagePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => InAppCameraCaptureScreen(
          title: widget.role == 'guardian'
              ? 'Capture learner selfie'
              : 'Capture your selfie',
          shape: CaptureFrameShape.oval,
          lensDirection: CameraLensDirection.front,
        ),
      ),
    );
    if (imagePath == null || !mounted) return;

    setState(() => _imagePath = imagePath);

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

    if (widget.role == 'guardian') {
      context.go(
        AppRoutes.guardianLicenseCapture,
        extra: {
          'role': widget.role,
          'licenseImagePath': licenseImagePath,
          'selfieImagePath': imagePath,
        },
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await SupabaseService.submitIdentityVerification(
        userId: user.id,
        role: widget.role,
        licenseImagePath: licenseImagePath,
        selfieImagePath: imagePath,
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

  @override
  Widget build(BuildContext context) {
    return IdentityCaptureScene(
      stepLabel: 'Step 3 of 4',
      title: widget.role == 'guardian'
          ? 'Position the learner within the oval'
          : 'Position your face within the oval',
      imagePath: _imagePath,
      shape: CaptureFrameShape.oval,
      onClose: () => context.pop(),
      onAction: _captureSelfie,
      onCapture: _captureSelfie,
      isBusy: _isSubmitting,
    );
  }
}
