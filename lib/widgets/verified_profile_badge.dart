import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

class VerifiedProfileBadge extends StatelessWidget {
  const VerifiedProfileBadge({
    super.key,
    this.size = 28,
    this.assetScale = 1,
    this.showCutout = false,
  });

  final double size;
  final double assetScale;
  final bool showCutout;

  @override
  Widget build(BuildContext context) {
    final badge = SizedBox(
      width: size,
      height: size,
      child: Transform.scale(
        scale: assetScale,
        child: SvgPicture.asset(
          'assets/icons/new-spiral-verified.svg',
        ),
      ),
    );

    if (!showCutout) return badge;

    final cutoutSize = size + 3;
    return SizedBox(
      width: cutoutSize,
      height: cutoutSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: 1.08,
            child: SvgPicture.asset(
              'assets/icons/new-spiral-verified.svg',
              width: size,
              height: size,
              colorFilter: const ColorFilter.mode(
                Color(0xFFFFFFFF),
                BlendMode.srcIn,
              ),
            ),
          ),
          badge,
        ],
      ),
    );
  }
}
