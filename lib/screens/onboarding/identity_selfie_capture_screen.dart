import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../widgets/guided_capture_frame.dart';
import '../../widgets/identity_capture_step_scaffold.dart';
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
  bool _isSubmitting = false;
  bool _didOpenCamera = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _captureSelfie();
    });
  }

  Future<void> _captureSelfie() async {
    if (_isSubmitting || _didOpenCamera) return;
    _didOpenCamera = true;

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
    if (!mounted) return;

    if (imagePath == null) {
      context.pop();
      return;
    }

    final licenseImagePath = widget.licenseImagePath;
    final user = SupabaseService.currentUser;

    if (licenseImagePath == null || user == null) {
      setState(() {
        _error = 'Unable to submit verification. Please try again.';
      });
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
      setState(() {
        _isSubmitting = false;
        _error = 'Unable to upload verification: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return IdentityCaptureStepScaffold(
      title: widget.role == 'guardian'
          ? 'Opening learner selfie camera'
          : 'Opening selfie camera',
      message: _isSubmitting
          ? 'Uploading your verification photos.'
          : 'Position the face inside the oval and tap the shutter once.',
      onClose: () => context.pop(),
      isBusy: _isSubmitting,
      error: _error,
      onRetry: () {
        setState(() {
          _didOpenCamera = false;
          _error = null;
        });
        _captureSelfie();
      },
    );
  }
}
