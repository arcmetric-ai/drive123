import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../widgets/guided_capture_frame.dart';
import '../../widgets/identity_capture_scene.dart';
import '../../widgets/in_app_camera_capture_screen.dart';

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
  String? _imagePath;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.guardianSelfieImagePath;
  }

  Future<void> _captureGuardianSelfie() async {
    if (_isSubmitting) return;

    final imagePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const InAppCameraCaptureScreen(
          title: 'Capture guardian selfie',
          shape: CaptureFrameShape.oval,
          lensDirection: CameraLensDirection.front,
        ),
      ),
    );

    final user = SupabaseService.currentUser;
    if (imagePath == null || user == null || !mounted) return;

    setState(() {
      _imagePath = imagePath;
      _isSubmitting = true;
    });

    try {
      await SupabaseService.submitIdentityVerification(
        userId: user.id,
        role: widget.role,
        licenseImagePath: widget.licenseImagePath,
        selfieImagePath: widget.selfieImagePath,
        guardianLicenseImagePath: widget.guardianLicenseImagePath,
        guardianSelfieImagePath: imagePath,
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
