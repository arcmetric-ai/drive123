import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_routes.dart';
import '../../widgets/guided_capture_frame.dart';
import '../../widgets/identity_capture_scene.dart';
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
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.licenseImagePath;
  }

  Future<void> _captureLicense() async {
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
    if (imagePath == null || !mounted) return;

    setState(() => _imagePath = imagePath);
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
    final title = widget.role == 'instructor'
        ? 'Position your Ontario G licence inside the frame'
        : 'Position your Ontario G1, G2, or G licence inside the frame';
    return IdentityCaptureScene(
      stepLabel: 'Step 2 of 4',
      title: title,
      imagePath: _imagePath,
      shape: CaptureFrameShape.rectangle,
      onClose: () => context.pop(),
      onAction: _captureLicense,
      onCapture: _captureLicense,
    );
  }
}
