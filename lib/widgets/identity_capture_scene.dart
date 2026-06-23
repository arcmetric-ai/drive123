import 'dart:io';

import 'package:flutter/material.dart';

import 'camera_shutter_button.dart';
import 'capture_stage_header.dart';
import 'guided_capture_frame.dart';

class IdentityCaptureScene extends StatelessWidget {
  const IdentityCaptureScene({
    super.key,
    required this.stepLabel,
    required this.title,
    required this.imagePath,
    required this.shape,
    required this.onClose,
    required this.onAction,
    required this.onCapture,
    this.isBusy = false,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String stepLabel;
  final String title;
  final String? imagePath;
  final CaptureFrameShape shape;
  final VoidCallback onClose;
  final VoidCallback onAction;
  final VoidCallback onCapture;
  final bool isBusy;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final backgroundImage =
        imagePath != null ? FileImage(File(imagePath!)) : null;
    final frameWidth = shape == CaptureFrameShape.oval ? 640.0 : 760.0;
    final frameHeight = shape == CaptureFrameShape.oval ? 680.0 : 470.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (backgroundImage != null)
            DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: backgroundImage,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF23242A), Color(0xFF09090B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black
                  .withValues(alpha: backgroundImage != null ? 0.38 : 0.54),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compactHeight = constraints.maxHeight < 760;
                final headerSpacing = compactHeight ? 72.0 : 120.0;
                final titleSpacing = compactHeight ? 24.0 : 42.0;
                final bottomSpacing = compactHeight ? 16.0 : 28.0;
                final shutterSize = compactHeight ? 84.0 : 96.0;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                  child: Column(
                    children: [
                      CaptureStageHeader(
                        stepLabel: stepLabel,
                        onClose: isBusy ? () {} : onClose,
                        onAction: isBusy ? null : onAction,
                      ),
                      SizedBox(height: headerSpacing),
                      Text(
                        title.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compactHeight ? 18 : 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: compactHeight ? 2.0 : 2.4,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Tap the shutter to open in-app camera capture.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: titleSpacing),
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            child: GuidedCaptureFrame(
                              shape: shape,
                              width: frameWidth,
                              height: frameHeight,
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: bottomSpacing),
                      if (secondaryActionLabel != null &&
                          onSecondaryAction != null) ...[
                        TextButton(
                          onPressed: isBusy ? null : onSecondaryAction,
                          child: Text(
                            secondaryActionLabel!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      CameraShutterButton(
                        onTap: onCapture,
                        isLoading: isBusy,
                        size: shutterSize,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
