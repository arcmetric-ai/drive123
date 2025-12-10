import 'dart:ui';

import 'package:flutter/material.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double opacity;
  final Color tintColor;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;

  const GlassPanel({
    super.key,
    required this.child,
    this.blurSigma = 14,
    this.opacity = 0.18,
    this.tintColor = Colors.white,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tintColor.withOpacity(opacity + 0.08),
                tintColor.withOpacity(opacity),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
