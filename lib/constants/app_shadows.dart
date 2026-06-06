import 'package:flutter/material.dart';

class AppShadows {
  static const List<BoxShadow> button = [
    BoxShadow(
      color: Color(0x1A054ADA),
      blurRadius: 28,
      offset: Offset(0, 12),
    ),
  ];

  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x0F111827),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];
}
