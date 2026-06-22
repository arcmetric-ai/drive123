import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../widgets/guided_capture_frame.dart';
import '../../widgets/identity_capture_scene.dart';

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
  final _imagePicker = ImagePicker();
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.guardianLicenseImagePath;
  }

  Future<void> _pickGuardianId(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _imagePath = picked.path);
    context.go(
      AppRoutes.guardianSelfieCapture,
      extra: {
        'role': widget.role,
        'licenseImagePath': widget.licenseImagePath,
        'selfieImagePath': widget.selfieImagePath,
        'guardianLicenseImagePath': picked.path,
      },
    );
  }

  Future<void> _captureGuardianId() async {
    try {
      await _pickGuardianId(ImageSource.camera);
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
        await _pickGuardianId(ImageSource.gallery);
      } catch (galleryError) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to select guardian ID image: $galleryError'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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
