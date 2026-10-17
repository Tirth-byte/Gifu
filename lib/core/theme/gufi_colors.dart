import 'package:flutter/material.dart';

/// Canonical Gufi Design System Color Tokens.
/// Source of Truth: Gufi Global UI Cleanup.
///
/// Rule: Gufi uses a clean, plain white canvas (#FFFFFF) with purposeful brand color.
class GufiColors {
  GufiColors._();

  // Canvas & Surfaces
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFFAFBFC);

  // Core Brand
  static const Color primary = Color(0xFF5880DA);
  static const Color softBlue = Color(0xFFBCDBFA);
  static const Color lime = Color(0xFFC9F17E);
  static const Color navy = Color(0xFF1E3365);

  // Supporting Neutrals & Semantics
  static const Color mutedSlate = Color(0xFF5C6E8C);
  static const Color textMuted = Color(0xFF768B9E);
  static const Color borderSubtle = Color(0xFFE2EAF4);
  static const Color borderFocus = Color(0xFF5880DA);
  static const Color error = Color(0xFFE5484D);
  static const Color success = Color(0xFF10B981);
}
