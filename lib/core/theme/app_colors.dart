import 'package:flutter/material.dart';

/// VERTIX Color Palette - Dark Premium Theme
/// NOT a Netflix copy - distinctive premium dark theme with subtle red accents
class AppColors {
  AppColors._();

  // ============================================
  // BACKGROUND COLORS
  // ============================================

  /// Main background - Pure dark
  static const Color background = Color(0xFF0A0A0A);

  /// Surface color for cards and containers
  static const Color surface = Color(0xFF141414);

  /// Lighter surface for elevated elements
  static const Color surfaceLight = Color(0xFF1E1E1E);

  /// Even lighter surface for hover states
  static const Color surfaceLighter = Color(0xFF2A2A2A);

  // ============================================
  // PRIMARY COLORS (Red accent)
  // ============================================

  /// Primary brand color - Subtle red
  static const Color primary = Color(0xFFE50914);

  /// Lighter primary for highlights
  static const Color primaryLight = Color(0xFFFF1F2A);

  /// Darker primary for pressed states
  static const Color primaryDark = Color(0xFFB20710);

  /// Subtle accent - Burgundy
  static const Color accent = Color(0xFF831010);

  /// Glow effect color (25% opacity red)
  static const Color accentGlow = Color(0x40E50914);

  // ============================================
  // TEXT COLORS
  // ============================================

  /// Primary text - Pure white
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Secondary text - Light gray
  static const Color textSecondary = Color(0xFFB3B3B3);

  /// Tertiary text - Medium gray
  static const Color textTertiary = Color(0xFF737373);

  /// Disabled text
  static const Color textDisabled = Color(0xFF4D4D4D);

  // ============================================
  // SEMANTIC COLORS
  // ============================================

  /// Success color - Green
  static const Color success = Color(0xFF46D369);

  /// Warning color - Yellow
  static const Color warning = Color(0xFFF5C518);

  /// Error color - Red (same as primary)
  static const Color error = Color(0xFFE50914);

  /// Info color - Blue
  static const Color info = Color(0xFF2196F3);

  // ============================================
  // INTERACTIVE COLORS
  // ============================================

  /// Like button active color
  static const Color likeActive = Color(0xFFE50914);

  /// Overlay color for video controls
  static const Color overlay = Color(0x80000000);

  /// Shimmer base color
  static const Color shimmerBase = Color(0xFF1E1E1E);

  /// Shimmer highlight color
  static const Color shimmerHighlight = Color(0xFF2A2A2A);

  // ============================================
  // GRADIENTS
  // ============================================

  /// Card gradient overlay (bottom to top darkness)
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0x40000000),
      Color(0xCC000000),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Premium gradient for special elements
  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE50914),
      Color(0xFF831010),
    ],
  );

  /// Vertical fade for video overlay
  static const LinearGradient videoOverlayGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00000000),
      Color(0x00000000),
      Color(0x80000000),
      Color(0xE6000000),
    ],
    stops: [0.0, 0.4, 0.7, 1.0],
  );

  // ============================================
  // MATERIAL COLOR SWATCH
  // ============================================

  static const MaterialColor primarySwatch = MaterialColor(
    0xFFE50914,
    <int, Color>{
      50: Color(0xFFFDE7E8),
      100: Color(0xFFF9C3C5),
      200: Color(0xFFF59B9F),
      300: Color(0xFFF17278),
      400: Color(0xFFEE545B),
      500: Color(0xFFE50914),
      600: Color(0xFFD00812),
      700: Color(0xFFB20710),
      800: Color(0xFF94060D),
      900: Color(0xFF64040A),
    },
  );
}
