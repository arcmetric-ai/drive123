import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_routes.dart';
import '../../widgets/guided_capture_frame.dart';
import '../../widgets/identity_capture_step_scaffold.dart';
import '../../widgets/in_app_camera_capture_screen.dart';

class GuardianLicenseCaptureScreen extends StatefulWidget {
  const GuardianLicenseCaptureScreen({
    super.key,
    required this.role,
    required this.licenseImagePath,
    required this.selfieImagePath,
    this.guardianLicenseImagePath,
  });

  final String role;
  final String licenseImagePath;
  final String selfieImagePath;
  final String? guardianLicenseImagePath;

  @override
  State<GuardianLicenseCaptureScreen> createState() =>
      _GuardianLicenseCaptureScreenState();
}

class _GuardianLicenseCaptureScreenState
    extends State<GuardianLicenseCaptureScreen> {
  bool _didOpenCamera = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _captureGuardianId();
    });
  }

  Future<void> _captureGuardianId() async {
    if (_didOpenCamera) return;
    _didOpenCamera = true;
    setState(() => _error = null);

    final imagePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const InAppCameraCaptureScreen(
          title: 'Capture guardian government ID',
          shape: CaptureFrameShape.rectangle,
        ),
      ),
    );
    if (!mounted) return;

    if (imagePath == null) {
      setState(() {
        _didOpenCamera = false;
        _error =
            'No guardian ID photo was captured. Open the camera to try again.';
      });
      return;
    }

    context.go(
      AppRoutes.guardianSelfieCapture,
      extra: {
        'role': widget.role,
        'licenseImagePath': widget.licenseImagePath,
        'selfieImagePath': widget.selfieImagePath,
        'guardianLicenseImagePath': imagePath,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IdentityCaptureStepScaffold(
      title: 'Opening guardian ID camera',
      message: 'Place the ID inside the frame and tap the shutter once.',
      onClose: () => context.go(
        AppRoutes.identityVerificationIntro,
        extra: widget.role,
      ),
      error: _error,
      onRetry: () {
        setState(() {
          _didOpenCamera = false;
          _error = null;
        });
        _captureGuardianId();
      },
    );
  }
}
