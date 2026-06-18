import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

class VerifiedProfileBadge extends StatelessWidget {
  const VerifiedProfileBadge({
    super.key,
    this.size = 28,
    this.assetScale = 1,
  });

  final double size;
  final double assetScale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Transform.scale(
        scale: assetScale,
        child: SvgPicture.asset(
          'assets/icons/verified_badge_full.svg',
        ),
      ),
    );
  }
}
