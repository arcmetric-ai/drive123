import 'package:flutter/material.dart';

class AppColors {
  // Theme tokens
  static const Color background = Color(0xFFFFFFFF);
  static const Color foreground = Color(0xFF111827);
  static const Color primary = Color(0xFF054ADA);
  static const Color primaryForeground = Color(0xFFFFFFFF);
  static const Color secondary = Color(0xFFF3F4F6);
  static const Color secondaryForeground = Color(0xFF111827);
  static const Color mutedForeground = Color(0xFF6B7280);
  static const Color accent = Color(0xFFFFD700);
  static const Color accentForeground = Color(0xFF000000);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardForeground = Color(0xFF111827);
  static const Color border = Color(0xFFE5E7EB);
  static const Color input = Color(0xFFFFFFFF);
  static const Color ring = primary;

  // Brand aliases
  static const Color brandPrimary = primary;
  static const Color brandPrimaryForeground = primaryForeground;
  static const Color brandAccent = accent;
  static const Color brandAccentForeground = accentForeground;
  static const Color brandMutedForeground = mutedForeground;

  // Core Palette
  static const Color ocean = brandPrimary;
  static const Color golden = brandAccent;
  static const Color dreamy = Color(0xFFF6FAFF);
  static const Color primaryBlue = ocean;
  static const Color primaryBlueDark = Color(0xFF1E40AF);

  // Light Theme Colors
  static const Color lightBackground = background;
  static const Color lightSurface = card;
  static const Color lightOnSurface = foreground;
  static const Color lightOnBackground = foreground;

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
    colors: [primary, primaryBlueDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, Color(0xFFFFF1A6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
