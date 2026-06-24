import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../widgets/guided_capture_frame.dart';
import '../../widgets/identity_capture_scene.dart';
import '../../widgets/in_app_camera_capture_screen.dart';

class VerificationDocumentResubmissionScreen extends StatefulWidget {
  const VerificationDocumentResubmissionScreen({
    super.key,
    required this.role,
    required this.documentType,
    this.requestId,
    this.adminMessage,
  });

  final String role;
  final String documentType;
  final String? requestId;
  final String? adminMessage;

  @override
  State<VerificationDocumentResubmissionScreen> createState() =>
      _VerificationDocumentResubmissionScreenState();
}

class _VerificationDocumentResubmissionScreenState
    extends State<VerificationDocumentResubmissionScreen> {
  String? _imagePath;
  bool _isSubmitting = false;

  bool get _isSelfie => widget.documentType.contains('selfie');

  CaptureFrameShape get _shape =>
      _isSelfie ? CaptureFrameShape.oval : CaptureFrameShape.rectangle;

  String get _documentTitle {
    switch (widget.documentType) {
      case 'identity_license':
        return widget.role == 'instructor'
            ? 'Ontario G licence'
            : 'Ontario G1, G2, or G licence';
      case 'identity_selfie':
        return 'Selfie photo';
      case 'guardian_identity_license':
        return 'Guardian government ID';
      case 'guardian_identity_selfie':
        return 'Guardian selfie photo';
      default:
        return 'Requested document';
    }
  }

  String get _sceneTitle => _isSelfie
      ? 'Position your face within the oval'
      : 'Position $_documentTitle inside the frame';

  String get _cameraTitle =>
      _isSelfie ? 'Capture $_documentTitle' : 'Capture $_documentTitle';

  Future<void> _captureAndSubmit() async {
    if (_isSubmitting) return;

    final imagePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => InAppCameraCaptureScreen(
          title: _cameraTitle,
          shape: _shape,
          lensDirection:
              _isSelfie ? CameraLensDirection.front : CameraLensDirection.back,
        ),
      ),
    );
    if (imagePath == null || !mounted) return;

    setState(() {
      _imagePath = imagePath;
      _isSubmitting = true;
    });

    final user = SupabaseService.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in again before uploading.'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      await SupabaseService.submitRequestedVerificationDocument(
        userId: user.id,
        role: widget.role,
        documentType: widget.documentType,
        imagePath: imagePath,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document uploaded for review.'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go(
        AppRoutes.identityPendingReview,
        extra: {'role': widget.role},
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to upload requested document: $error'),
          backgroundColor: AppColors.error,
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IdentityCaptureScene(
      stepLabel: 'Action needed',
      title: _sceneTitle,
      imagePath: _imagePath,
      shape: _shape,
      onClose: () => context.go(
        AppRoutes.identityPendingReview,
        extra: {'role': widget.role},
      ),
      onAction: _captureAndSubmit,
      onCapture: _captureAndSubmit,
      isBusy: _isSubmitting,
    );
  }
}
