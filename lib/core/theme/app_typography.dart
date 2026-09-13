import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Central typography architecture for Gufi.
///
/// DISPLAY / EMOTIONAL TEXT:
/// Gambarino is the intended display typeface (greetings, milestone counts, major editorial moments).
/// When font assets are available, set [gambarinoFontFamily] = 'Gambarino'.
/// While null, an elegant editorial serif (Newsreader via GoogleFonts) serves as the luxury fallback.
///
/// UI / FUNCTIONAL TEXT:
/// Inter provides crisp, modern, legible contrast for buttons, tasks, navigation, and metadata.
class AppTypography {
  AppTypography._();

  /// Central plug-in point for the Gambarino typeface.
  /// Activated with assets/fonts/Gambarino-Regular.ttf.
  static const String gambarinoFontFamily = 'Gambarino';

  static TextStyle _displayStyle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w400,
    double height = 1.15,
    double letterSpacing = -0.3,
    Color color = AppColors.textPrimary,
    FontStyle fontStyle = FontStyle.normal,
  }) {
    return TextStyle(
      fontFamily: gambarinoFontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontStyle: fontStyle,
    );
  }

  // --- Display / Emotional Typography (Gambarino Architecture) ---

  /// Greeting salutation ("Good evening,")
  static TextStyle get greetingSalutation => _displayStyle(
    fontSize: 26,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.4,
    height: 1.15,
    color: AppColors.textSecondary,
  );

  /// Greeting name ("Tirth.")
  static TextStyle get greetingName => _displayStyle(
    fontSize: 34,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.6,
    height: 1.15,
    color: AppColors.textPrimary,
  );

  /// Primary commitment statement ("What are you committing to today?")
  static TextStyle get commitmentStatement => _displayStyle(
    fontSize: 27,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.4,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  /// Launch screen hero wordmark ("Gufi")
  static TextStyle get launchWordmark => _displayStyle(
    fontSize: 54,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.9,
    height: 1.1,
    color: const Color(0xFF171821),
  );

  /// Launch screen understated tagline ("Grow together.")
  static TextStyle get launchTagline => GoogleFonts.inter(
    fontSize: 12.0,
    fontWeight: FontWeight.w400,
    letterSpacing: 2.2,
    height: 1.2,
    color: const Color(0xFF868C9E),
  );

  /// Launch screen subtitle under Gufi ("A STRONGER YOU TOGETHER")
  static TextStyle get launchSubtitle => GoogleFonts.inter(
    fontSize: 9.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.6,
    height: 1.45,
    color: const Color(0xFF7A8098),
  );

  /// Launch screen top-right micro text ("Commit / Do / Grow Together")
  static TextStyle get launchTopMicro => GoogleFonts.inter(
    fontSize: 9.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.4,
    height: 1.5,
    color: const Color(0xFF8E95AA),
  );

  /// Launch screen bottom brand text ("BUILT FOR REAL PROGRESS")
  static TextStyle get launchBottomBrand => GoogleFonts.inter(
    fontSize: 9.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 3.2,
    height: 1.2,
    color: const Color(0xFF8E94A8),
  );

  /// Intro / Onboarding primary headline ("Commit. Show up.\nGrow together.")
  static TextStyle get introHeadline => _displayStyle(
    fontSize: 34.0,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.6,
    height: 1.15,
    color: AppColors.textPrimary,
  );

  /// Onboarding secondary body copy
  static TextStyle get onboardingBody => GoogleFonts.inter(
    fontSize: 15.0,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  /// General display large
  static TextStyle get displayLarge => _displayStyle(
    fontSize: 36,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.8,
    height: 1.1,
  );

  /// General display medium
  static TextStyle get displayMedium => _displayStyle(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.5,
    height: 1.15,
  );

  /// General display small
  static TextStyle get displaySmall => _displayStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.3,
    height: 1.2,
  );

  // --- Functional UI Typography (Inter) ---

  /// Header brand wordmark ("GUFI")
  static TextStyle get brandWordmark => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.2,
    color: AppColors.textPrimary,
  );

  /// Micro section header ("TODAY", "DAILY ACCOUNTABILITY")
  static TextStyle get sectionHeader => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: AppColors.textMuted,
  );

  /// Main card title / accountability title
  static TextStyle get cardTitle => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  /// Card body copy
  static TextStyle get cardBody => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  /// Compact button text
  static TextStyle get button => GoogleFonts.inter(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: AppColors.primaryDeep,
  );

  /// Small button text
  static TextStyle get buttonSmall => GoogleFonts.inter(
    fontSize: 12.0,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: AppColors.primaryDeep,
  );

  /// Secondary / helper caption
  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 12.0,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: AppColors.textSecondary,
  );

  /// Streak chip text ("✦ 13 day streak")
  static TextStyle get streakPill => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: AppColors.primaryDeep,
  );

  /// Navigation item label
  static TextStyle get navLabel => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: AppColors.textSecondary,
  );

  /// General body large
  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.textPrimary,
  );

  /// General body medium
  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  /// General body small
  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: AppColors.textMuted,
  );

  /// Micro metadata
  static TextStyle get micro => GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: AppColors.textMuted,
  );
}
