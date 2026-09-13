import 'package:flutter/material.dart';

/// Centralized color palette and tokens for Gufi.
///
/// Source of Truth: Reference 2 (Color System)
/// "One navy. Two accents. That's it."
///
/// Palette Anchors:
/// - Navy 900: #273869 (Primary brand & high-emphasis text)
/// - Navy 800: #405881 (Secondary accent & mid-emphasis text)
/// - Gray 50:  #EDF1F4 (Restrained cool pale canvas)
class AppColors {
  AppColors._();

  // Reference 2 Palette Anchors
  static const Color navy900 = Color(0xFF273869);
  static const Color navy800 = Color(0xFF405881);
  static const Color gray50 = Color(0xFFEDF1F4);

  // Canvas & Backgrounds
  static const Color background = gray50;
  static const Color canvasTop = gray50;
  static const Color canvasMid = gray50;
  static const Color canvasBottom = Color(0xFFE4E9EE);
  static const Color backgroundSecondary = Color(0xFFE5EBEF);

  // Surfaces (Soft, clean white & neutral tint)
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF7FAFC);
  static const Color surfaceInteractive = Color(0xFFEAEFF5);

  // Typography
  static const Color textPrimary = navy900;
  static const Color textSecondary = navy800;
  static const Color textMuted = Color(0xFF768B9E);
  static const Color textDisabled = Color(0xFFA5B4C2);

  // Brand / Accents
  static const Color primary = navy900;
  static const Color primaryLight = navy800;
  static const Color primaryPale = Color(0xFFE8EEF5);
  static const Color primarySubtle = Color(0xFFDFE7F0);
  static const Color primarySubtleBorder = Color(0xFFCBD8E6);

  // Hairlines & Dividers
  static const Color borderSubtle = Color(0x24273869);
  static const Color borderMedium = Color(0x40273869);

  // Reference 1: Soft Diffused Low-Contrast Shadows
  static const List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Color(0x0A273869),
      blurRadius: 14,
      spreadRadius: 0,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> shadowMd = [
    BoxShadow(
      color: Color(0x12273869),
      blurRadius: 24,
      spreadRadius: 0,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> shadowLg = [
    BoxShadow(
      color: Color(0x18273869),
      blurRadius: 36,
      spreadRadius: 0,
      offset: Offset(0, 14),
    ),
  ];

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color successSubtle = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSubtle = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color destructive = Color(0xFFEF4444);
  static const Color destructiveSubtle = Color(0xFFFEE2E2);

  // Core widget aliases
  static const Color primaryDeep = navy900;
  static const Color glassBackground = Color(0xD9FFFFFF);
  static const Color glassBorder = Color(0x38BDD4E7);
}
