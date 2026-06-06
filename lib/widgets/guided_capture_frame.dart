import 'dart:math' as math;

import 'package:flutter/material.dart';

enum CaptureFrameShape { rectangle, oval }

class GuidedCaptureFrame extends StatelessWidget {
  const GuidedCaptureFrame({
    super.key,
    required this.shape,
    required this.child,
    this.width = 760,
    this.height = 470,
  });

  final CaptureFrameShape shape;
  final Widget child;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(width, height),
            painter: _FramePainter(shape: shape),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter({required this.shape});

  final CaptureFrameShape shape;

  @override
  void paint(Canvas canvas, Size size) {
    final outerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final dashedPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (shape == CaptureFrameShape.oval) {
      canvas.drawOval(rect, outerPaint);
      _drawDashedPath(
        canvas,
        dashedPaint,
        Path()..addOval(rect.deflate(22)),
      );
    } else {
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(28));
      canvas.drawRRect(rrect, outerPaint);
      _drawDashedPath(
        canvas,
        dashedPaint,
        Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              rect.deflate(10),
              const Radius.circular(24),
            ),
          ),
      );
    }
  }

  void _drawDashedPath(Canvas canvas, Paint paint, Path path) {
    const dashWidth = 12.0;
    const dashSpace = 8.0;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FramePainter oldDelegate) {
    return oldDelegate.shape != shape;
  }
}
