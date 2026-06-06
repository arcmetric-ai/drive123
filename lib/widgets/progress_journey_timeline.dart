import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radii.dart';
import '../constants/app_shadows.dart';
import '../constants/app_spacing.dart';

enum ProgressJourneyStepState {
  completed,
  current,
  locked,
}

class ProgressJourneyStepData {
  const ProgressJourneyStepData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.state,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final ProgressJourneyStepState state;
  final VoidCallback? onTap;
}

class ProgressJourneyTimeline extends StatelessWidget {
  const ProgressJourneyTimeline({
    super.key,
    required this.steps,
  });

  final List<ProgressJourneyStepData> steps;

  static const double _stepExtent = 186;
  static const List<double> _lanePattern = <double>[
    0.56,
    0.64,
    0.52,
    0.40,
    0.46,
    0.60,
    0.54,
    0.42,
  ];

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final centers = List<Offset>.generate(steps.length, (index) {
          final x = width * _lanePattern[index % _lanePattern.length];
          final y = 92 + (index * _stepExtent);
          return Offset(x, y);
        });

        final height = (steps.length * _stepExtent) + 24;

        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _JourneyPathPainter(
                    centers: centers,
                    currentIndex: steps.indexWhere(
                      (step) => step.state == ProgressJourneyStepState.current,
                    ),
                  ),
                ),
              ),
              for (var index = 0; index < steps.length; index++)
                _JourneyStepLayout(
                  step: steps[index],
                  center: centers[index],
                  width: width,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _JourneyStepLayout extends StatelessWidget {
  const _JourneyStepLayout({
    required this.step,
    required this.center,
    required this.width,
  });

  final ProgressJourneyStepData step;
  final Offset center;
  final double width;

  @override
  Widget build(BuildContext context) {
    final nodeSize =
        step.state == ProgressJourneyStepState.current ? 98.0 : 72.0;
    final labelOnLeft = center.dx > width * 0.5;
    final horizontalGap =
        step.state == ProgressJourneyStepState.current ? 26.0 : 22.0;
    final top = center.dy - (nodeSize / 2);
    final availableWidth = labelOnLeft
        ? center.dx - (nodeSize / 2) - horizontalGap - 12
        : width - center.dx - (nodeSize / 2) - horizontalGap - 12;
    final labelWidth = availableWidth.clamp(150.0, 220.0);
    final labelHeight =
        step.state == ProgressJourneyStepState.current ? 144.0 : 116.0;
    final labelTop = center.dy - (labelHeight / 2);
    final labelLeft = labelOnLeft
        ? math.max(0.0, center.dx - (nodeSize / 2) - horizontalGap - labelWidth)
        : math.min(
            width - labelWidth,
            center.dx + (nodeSize / 2) + horizontalGap,
          );

    return Stack(
      children: [
        Positioned(
          left: labelLeft,
          top: labelTop,
          width: labelWidth,
          height: labelHeight,
          child: Align(
            alignment:
                labelOnLeft ? Alignment.centerRight : Alignment.centerLeft,
            child: _JourneyLabel(
              step: step,
              alignLeft: labelOnLeft,
            ),
          ),
        ),
        Positioned(
          left: center.dx - (nodeSize / 2),
          top: top,
          child: _JourneyNode(
            step: step,
            size: nodeSize,
          ),
        ),
      ],
    );
  }
}

class _JourneyLabel extends StatelessWidget {
  const _JourneyLabel({
    required this.step,
    required this.alignLeft,
  });

  final ProgressJourneyStepData step;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) {
    final textAlign = alignLeft ? TextAlign.right : TextAlign.left;
    final crossAxisAlignment =
        alignLeft ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          step.title,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: step.state == ProgressJourneyStepState.current ? 18 : 16,
            fontWeight: FontWeight.w800,
            height: 1.25,
            color: step.state == ProgressJourneyStepState.locked
                ? AppColors.mutedForeground
                : AppColors.foreground,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (step.state == ProgressJourneyStepState.current)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: const Text(
              'IN PROGRESS',
              style: TextStyle(
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: AppColors.primary,
              ),
            ),
          )
        else
          Text(
            step.state == ProgressJourneyStepState.completed
                ? 'MASTERED'
                : 'LOCKED',
            textAlign: textAlign,
            style: TextStyle(
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: step.state == ProgressJourneyStepState.completed
                  ? AppColors.primary
                  : AppColors.grey400,
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          step.subtitle,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.35,
            color: step.state == ProgressJourneyStepState.locked
                ? AppColors.grey400
                : AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _JourneyNode extends StatelessWidget {
  const _JourneyNode({
    required this.step,
    required this.size,
  });

  final ProgressJourneyStepData step;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isCurrent = step.state == ProgressJourneyStepState.current;
    final isCompleted = step.state == ProgressJourneyStepState.completed;
    final backgroundColor = isCurrent
        ? AppColors.primary
        : isCompleted
            ? AppColors.accent
            : AppColors.grey100;
    final iconColor = isCurrent
        ? AppColors.primaryForeground
        : isCompleted
            ? AppColors.accentForeground
            : AppColors.grey400;

    return GestureDetector(
      onTap: step.onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(isCurrent ? 28 : 22),
          border: Border.all(
            color: isCurrent ? AppColors.card : AppColors.border,
            width: isCurrent ? 7 : 1.5,
          ),
          boxShadow: [
            if (isCurrent)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.24),
                blurRadius: 30,
                spreadRadius: 6,
              ),
            ...AppShadows.subtle,
          ],
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            step.icon,
            size: isCurrent ? 30 : 26,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}

class _JourneyPathPainter extends CustomPainter {
  const _JourneyPathPainter({
    required this.centers,
    required this.currentIndex,
  });

  final List<Offset> centers;
  final int currentIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (centers.length < 2) return;

    final solidPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.28)
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final futurePaint = Paint()
      ..color = AppColors.grey300
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final completedPath = _buildSmoothPath(
      centers
          .take(
            currentIndex >= 0
                ? math.min(currentIndex + 1, centers.length)
                : centers.length,
          )
          .toList(),
    );
    canvas.drawPath(completedPath, solidPaint);

    if (currentIndex >= 0 && currentIndex < centers.length - 1) {
      final futureCenters = centers.sublist(currentIndex);
      final futurePath = _buildSmoothPath(futureCenters);
      _drawDottedPath(canvas, futurePath, futurePaint);
    }
  }

  Path _buildSmoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    if (points.length == 1) return path;

    for (var index = 0; index < points.length - 1; index++) {
      final current = points[index];
      final next = points[index + 1];
      final controlY = (current.dy + next.dy) / 2;
      path.cubicTo(
        current.dx,
        controlY,
        next.dx,
        controlY,
        next.dx,
        next.dy,
      );
    }
    return path;
  }

  void _drawDottedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final segment = metric.extractPath(distance, distance + 10);
        canvas.drawPath(segment, paint);
        distance += 20;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _JourneyPathPainter oldDelegate) {
    return oldDelegate.centers != centers ||
        oldDelegate.currentIndex != currentIndex;
  }
}
