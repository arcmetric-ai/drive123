import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_routes.dart';
import '../../widgets/guided_capture_frame.dart';
import '../../widgets/identity_capture_scene.dart';
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
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.guardianLicenseImagePath;
  }

  Future<void> _captureGuardianId() async {
    final imagePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const InAppCameraCaptureScreen(
          title: 'Capture guardian government ID',
          shape: CaptureFrameShape.rectangle,
        ),
      ),
    );
    if (imagePath == null || !mounted) return;

    setState(() => _imagePath = imagePath);
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
    return IdentityCaptureScene(
      stepLabel: 'Guardian Step 1 of 2',
      title: 'Position guardian government ID inside the frame',
      imagePath: _imagePath,
      shape: CaptureFrameShape.rectangle,
      onClose: () => context.pop(),
      onAction: _captureGuardianId,
      onCapture: _captureGuardianId,
    );
  }
}
