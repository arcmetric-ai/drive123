import 'package:flutter/material.dart';

class CameraShutterButton extends StatelessWidget {
  const CameraShutterButton({
    super.key,
    required this.onTap,
    this.isLoading = false,
    this.size = 96,
  });

  final VoidCallback onTap;
  final bool isLoading;
  final double size;

  @override
  Widget build(BuildContext context) {
    final borderWidth = size <= 84 ? 5.0 : 6.0;
    final innerPadding = size <= 84 ? 8.0 : 10.0;
    final loaderSize = size <= 84 ? 24.0 : 28.0;
    final loaderStroke = size <= 84 ? 2.2 : 2.6;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isLoading ? null : onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: borderWidth),
          ),
          padding: EdgeInsets.all(innerPadding),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: isLoading
                ? Center(
                    child: SizedBox(
                      width: loaderSize,
                      height: loaderSize,
                      child: CircularProgressIndicator(
                        strokeWidth: loaderStroke,
                        color: Colors.black,
                      ),
                    ),
                  )
                : const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
