import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../widgets/guided_capture_frame.dart';
import '../../widgets/identity_capture_step_scaffold.dart';
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
  static const _frontCameraWarmupDelay = Duration(milliseconds: 700);
  bool _isSubmitting = false;
  bool _didOpenCamera = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _captureGuardianSelfie();
    });
  }

  Future<void> _captureGuardianSelfie() async {
    if (_isSubmitting || _didOpenCamera) return;
    _didOpenCamera = true;
    setState(() => _error = null);

    await Future<void>.delayed(_frontCameraWarmupDelay);
    if (!mounted) return;

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
    if (!mounted) return;
    if (imagePath == null) {
      setState(() {
        _didOpenCamera = false;
        _error =
            'No guardian selfie was captured. Open the camera to try again.';
      });
      return;
    }
    if (user == null) {
      setState(() {
        _error = 'Please sign in again before uploading.';
      });
      return;
    }

    setState(() {
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
      setState(() {
        _isSubmitting = false;
        _error = 'Unable to upload guardian consent: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return IdentityCaptureStepScaffold(
      title: 'Opening guardian selfie camera',
      message: _isSubmitting
          ? 'Uploading guardian verification photos.'
          : 'Position the guardian face inside the oval and tap the shutter once.',
      onClose: () => context.go(
        AppRoutes.identityVerificationIntro,
        extra: widget.role,
      ),
      isBusy: _isSubmitting,
      error: _error,
      onRetry: () {
        setState(() {
          _didOpenCamera = false;
          _error = null;
        });
        _captureGuardianSelfie();
      },
    );
  }
}
