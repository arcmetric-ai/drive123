import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class VerifiedProfileBadge extends StatelessWidget {
  const VerifiedProfileBadge({
    super.key,
    this.size = 28,
    this.borderWidth = 2,
    this.assetPadding = 0,
    this.assetScale = 1.16,
  });

  final double size;
  final double borderWidth;
  final double assetPadding;
  final double assetScale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(assetPadding),
        child: Transform.scale(
          scale: assetScale,
          child: SvgPicture.asset(
            'assets/icons/verified_badge_full.svg',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
