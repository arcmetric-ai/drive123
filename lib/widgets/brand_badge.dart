import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BrandBadge extends StatelessWidget {
  const BrandBadge({
    super.key,
    this.size = 112,
    this.backgroundColor,
    this.padding = EdgeInsets.zero,
    this.borderRadius = 24,
    this.contentScale = 1.7,
  });

  static const String _logoAsset = 'assets/images/new_logo.svg';

  final double size;
  final Color? backgroundColor;
  final EdgeInsets padding;
  final double borderRadius;
  final double contentScale;

  @override
  Widget build(BuildContext context) {
    final logo = SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Transform.scale(
          scale: contentScale,
          child: SvgPicture.asset(
            _logoAsset,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );

    if (backgroundColor == null) {
      return logo;
    }

    return Container(
      width: size,
      height: size,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Transform.scale(
          scale: contentScale,
          child: SvgPicture.asset(
            _logoAsset,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
