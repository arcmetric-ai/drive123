import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_routes.dart';
import '../../widgets/guided_capture_frame.dart';
import '../../widgets/identity_capture_step_scaffold.dart';
import '../../widgets/in_app_camera_capture_screen.dart';

class IdentityLicenseCaptureScreen extends StatefulWidget {
  const IdentityLicenseCaptureScreen({
    super.key,
    required this.role,
    this.licenseImagePath,
  });

  final String role;
  final String? licenseImagePath;

  @override
  State<IdentityLicenseCaptureScreen> createState() =>
      _IdentityLicenseCaptureScreenState();
}

class _IdentityLicenseCaptureScreenState
    extends State<IdentityLicenseCaptureScreen> {
  bool _didOpenCamera = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _captureLicense();
    });
  }

  Future<void> _captureLicense() async {
    if (_didOpenCamera) return;
    _didOpenCamera = true;
    setState(() => _error = null);

    final title = widget.role == 'instructor'
        ? 'Capture your Ontario G licence'
        : 'Capture your Ontario G1, G2, or G licence';
    final imagePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => InAppCameraCaptureScreen(
          title: title,
          shape: CaptureFrameShape.rectangle,
        ),
      ),
    );
    if (!mounted) return;

    if (imagePath == null) {
      setState(() {
        _didOpenCamera = false;
        _error = 'No photo was captured. Open the camera to try again.';
      });
      return;
    }

    context.go(
      AppRoutes.identitySelfieCapture,
      extra: {
        'role': widget.role,
        'licenseImagePath': imagePath,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IdentityCaptureStepScaffold(
      title: 'Opening licence camera',
      message: 'Place the licence inside the frame and tap the shutter once.',
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
        _captureLicense();
      },
    );
  }
}
