import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_routes.dart';
import '../../services/supabase_service.dart';
import '../../widgets/guided_capture_frame.dart';
import '../../widgets/identity_capture_step_scaffold.dart';
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
  static const _frontCameraWarmupDelay = Duration(milliseconds: 700);
  bool _isSubmitting = false;
  bool _didOpenCamera = false;
  String? _error;

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

  String get _cameraTitle =>
      _isSelfie ? 'Capture $_documentTitle' : 'Capture $_documentTitle';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _captureAndSubmit();
    });
  }

  Future<void> _captureAndSubmit() async {
    if (_isSubmitting || _didOpenCamera) return;
    _didOpenCamera = true;

    if (_isSelfie) {
      await Future<void>.delayed(_frontCameraWarmupDelay);
      if (!mounted) return;
    }

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
    if (!mounted) return;

    if (imagePath == null) {
      context.go(
        AppRoutes.identityPendingReview,
        extra: {'role': widget.role},
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final user = SupabaseService.currentUser;
    if (user == null) {
      setState(() {
        _isSubmitting = false;
        _error = 'Please sign in again before uploading.';
      });
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
      setState(() {
        _isSubmitting = false;
        _error = 'Unable to upload requested document: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return IdentityCaptureStepScaffold(
      title: 'Opening $_documentTitle camera',
      message: _isSubmitting
          ? 'Uploading $_documentTitle.'
          : _isSelfie
              ? 'Position the face inside the oval and tap the shutter once.'
              : 'Place $_documentTitle inside the frame and tap the shutter once.',
      onClose: () => context.go(
        AppRoutes.identityPendingReview,
        extra: {'role': widget.role},
      ),
      isBusy: _isSubmitting,
      error: _error,
      onRetry: () {
        setState(() {
          _didOpenCamera = false;
          _error = null;
        });
        _captureAndSubmit();
      },
    );
  }
}
