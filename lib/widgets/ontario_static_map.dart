import 'package:flutter/material.dart';

class OntarioStaticMap extends StatelessWidget {
  const OntarioStaticMap({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF7F5EF), Color(0xFFF2EFE7)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: CustomPaint(
        painter: _OntarioMapPainter(),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _OntarioMapPainter extends CustomPainter {
  const _OntarioMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final minorRoadPaint = Paint()
      ..color = const Color(0x15111827)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final highwayPaint = Paint()
      ..color = const Color(0xA6111827)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2;
    final waterPaint = Paint()
      ..color = const Color(0xFF63A7F7)
      ..style = PaintingStyle.fill;

    final waterPath = Path()
      ..moveTo(0, size.height * 0.67)
      ..cubicTo(
        size.width * 0.12,
        size.height * 0.63,
        size.width * 0.22,
        size.height * 0.7,
        size.width * 0.34,
        size.height * 0.69,
      )
      ..cubicTo(
        size.width * 0.54,
        size.height * 0.67,
        size.width * 0.63,
        size.height * 0.84,
        size.width,
        size.height * 0.76,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(waterPath, waterPaint);

    for (int i = -2; i < 12; i++) {
      final y = size.height * 0.1 + i * 42;
      final path = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(
          size.width * 0.38,
          y - 20 + (i.isEven ? 12 : -10),
          size.width,
          y + 8,
        );
      canvas.drawPath(path, minorRoadPaint);
    }

    for (int i = -1; i < 10; i++) {
      final x = size.width * 0.08 + i * 48;
      final path = Path()
        ..moveTo(x, 0)
        ..quadraticBezierTo(
          x - 10 + (i.isEven ? 8 : -8),
          size.height * 0.35,
          x + 12,
          size.height,
        );
      canvas.drawPath(path, minorRoadPaint);
    }

    final northSouthHighway = Path()
      ..moveTo(size.width * 0.83, 0)
      ..cubicTo(
        size.width * 0.86,
        size.height * 0.18,
        size.width * 0.78,
        size.height * 0.44,
        size.width * 0.86,
        size.height * 0.77,
      );
    canvas.drawPath(northSouthHighway, highwayPaint);

    final lakeShore = Path()
      ..moveTo(0, size.height * 0.61)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.58,
        size.width * 0.44,
        size.height * 0.61,
        size.width,
        size.height * 0.56,
      );
    canvas.drawPath(lakeShore, highwayPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
