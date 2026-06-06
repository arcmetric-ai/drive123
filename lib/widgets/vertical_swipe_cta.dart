import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radii.dart';
import '../constants/app_shadows.dart';

class VerticalSwipeCta extends StatefulWidget {
  const VerticalSwipeCta({
    super.key,
    required this.onComplete,
    this.height = 232,
    this.width = 112,
  });

  final VoidCallback onComplete;
  final double height;
  final double width;

  @override
  State<VerticalSwipeCta> createState() => _VerticalSwipeCtaState();
}

class _VerticalSwipeCtaState extends State<VerticalSwipeCta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _progress = 0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        setState(() {
          _progress = _controller.value;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _travelDistance => widget.height - widget.width;

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_completed) return;
    final delta = -(details.primaryDelta ?? 0) / _travelDistance;
    _progress = (_progress + delta).clamp(0.0, 1.0);
    _controller.value = _progress;
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_completed) return;
    if (_progress >= 0.82) {
      _completed = true;
      _controller.animateTo(1).whenComplete(() {
        if (mounted) widget.onComplete();
      });
      return;
    }
    _controller.animateBack(0, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final knobOffset = (1 - _progress) * _travelDistance;

    return GestureDetector(
      onVerticalDragUpdate: _handleVerticalDragUpdate,
      onVerticalDragEnd: _handleVerticalDragEnd,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          boxShadow: AppShadows.button,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: CustomPaint(
                  painter: _DotPatternPainter(),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: _completed
                  ? const Duration(milliseconds: 160)
                  : Duration.zero,
              curve: Curves.easeOut,
              left: 16,
              right: 16,
              top: knobOffset + 16,
              child: Container(
                width: widget.width - 32,
                height: widget.width - 32,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: AppColors.foreground,
                  size: 42,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.18);
    const spacing = 20.0;
    const radius = 1.5;

    for (double y = 12; y < size.height; y += spacing) {
      for (double x = 12; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
