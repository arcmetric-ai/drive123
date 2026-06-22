import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../widgets/guided_capture_frame.dart';
import '../../widgets/identity_capture_scene.dart';

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
  static const _testingBypassEnabled = true;
  final _imagePicker = ImagePicker();
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.licenseImagePath;
  }

  Future<void> _pickLicense(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _imagePath = picked.path);
    context.go(
      AppRoutes.identitySelfieCapture,
      extra: {
        'role': widget.role,
        'licenseImagePath': picked.path,
      },
    );
  }

  Future<void> _captureLicense() async {
    try {
      await _pickLicense(ImageSource.camera);
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
        await _pickLicense(ImageSource.gallery);
      } catch (galleryError) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to select ID image: $galleryError'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _skipForTesting() {
    context.go(
      AppRoutes.identitySelfieCapture,
      extra: {
        'role': widget.role,
        'licenseImagePath': _imagePath,
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
      secondaryActionLabel: _testingBypassEnabled ? 'Skip for testing' : null,
      onSecondaryAction: _testingBypassEnabled ? _skipForTesting : null,
    );
  }
}
