import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'camera_shutter_button.dart';
import 'capture_stage_header.dart';
import 'guided_capture_frame.dart';

class InAppCameraCaptureScreen extends StatefulWidget {
  const InAppCameraCaptureScreen({
    super.key,
    required this.title,
    required this.shape,
    this.lensDirection = CameraLensDirection.back,
  });

  final String title;
  final CaptureFrameShape shape;
  final CameraLensDirection lensDirection;

  @override
  State<InAppCameraCaptureScreen> createState() =>
      _InAppCameraCaptureScreenState();
}

class _InAppCameraCaptureScreenState extends State<InAppCameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _error;
  int _initializationToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    _initializationToken += 1;
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _initializationToken += 1;
      _controller = null;
      final disposeFuture = controller?.dispose();
      if (disposeFuture != null) unawaited(disposeFuture);
      if (mounted) {
        setState(() {
          _isInitializing = true;
          _isCapturing = false;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    final token = ++_initializationToken;
    setState(() {
      _isInitializing = true;
      _error = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('noCamera', 'No camera was found.');
      }

      final camera = cameras.firstWhere(
        (candidate) => candidate.lensDirection == widget.lensDirection,
        orElse: () => cameras.first,
      );

      final previousController = _controller;
      _controller = null;
      await previousController?.dispose();
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();

      if (!mounted || token != _initializationToken) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
      });
    } on CameraException catch (error) {
      if (!mounted || token != _initializationToken) return;
      final denied = error.code == 'CameraAccessDenied' ||
          error.code == 'CameraAccessDeniedWithoutPrompt' ||
          error.code == 'CameraAccessRestricted';
      setState(() {
        _isInitializing = false;
        _error = denied
            ? 'Camera permission is required to take this verification photo.'
            : 'Unable to start the camera. Please try again.';
      });
    } catch (_) {
      if (!mounted || token != _initializationToken) return;
      setState(() {
        _isInitializing = false;
        _error = 'Unable to start the camera. Please try again.';
      });
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (_isCapturing ||
        controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }

    setState(() => _isCapturing = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) return;
      setState(() => _isCapturing = false);
      Navigator.of(context).pop(file.path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to capture photo. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final frameWidth = widget.shape == CaptureFrameShape.oval ? 640.0 : 760.0;
    final frameHeight = widget.shape == CaptureFrameShape.oval ? 680.0 : 470.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildCameraLayer(),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.24),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                children: [
                  CaptureStageHeader(
                    stepLabel: 'Camera',
                    onClose: () => Navigator.of(context).pop(),
                    onAction: _isInitializing ? null : _takePicture,
                  ),
                  const Spacer(),
                  Text(
                    widget.title.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FittedBox(
                    child: GuidedCaptureFrame(
                      shape: widget.shape,
                      width: frameWidth,
                      height: frameHeight,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  const Spacer(),
                  CameraShutterButton(
                    onTap: _takePicture,
                    isLoading: _isCapturing,
                    size: 88,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraLayer() {
    final controller = _controller;
    if (_isInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final error = _error;
    if (error != null ||
        controller == null ||
        !controller.value.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.photo_camera_outlined,
                color: Colors.white,
                size: 52,
              ),
              const SizedBox(height: 18),
              Text(
                error ?? 'Unable to start the camera.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              TextButton(
                onPressed: _initializeCamera,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return Center(child: CameraPreview(controller));
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}
