import 'package:flutter/material.dart';

class AppColors {
  // Core Palette
  static const Color ocean = Color(0xFF9F6361);
  static const Color golden = Color(0xFF9DF900);
  static const Color dreamy = Color(0xFFEAEBED);
  static const Color primaryBlue = ocean;

  // Light Theme Colors
  static const Color lightBackground = dreamy;
  static const Color lightSurface = Color(0xFFF4F5F6);
  static const Color lightOnSurface = Color(0xFF0F2F38);
  static const Color lightOnBackground = Color(0xFF0F2F38);

  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF02141A);
  static const Color darkSurface = Color(0xFF06232B);
  static const Color darkOnSurface = dreamy;
  static const Color darkOnBackground = dreamy;

  // Neutral Colors
  static const Color grey50 = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey700 = Color(0xFF374151);
  static const Color grey800 = Color(0xFF1F2937);
  static const Color grey900 = Color(0xFF111827);
  
  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
  
  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [ocean, Color(0xFF004F68)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    colors: [golden, Color(0xFF9CF7B5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
