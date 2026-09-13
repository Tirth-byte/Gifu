import 'package:flutter/services.dart';

/// Centralized tactile haptics abstraction for Gufi.
/// Encapsulates platform feedback calls safely with distinct semantic levels.
class AppHaptics {
  AppHaptics._();

  /// Very light selection tap for standard UI interactions, tabs, and toggles.
  static Future<void> selection() async {
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Subtle light impact for button presses and micro interactions.
  static Future<void> light() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Distinct medium impact for affirmative state changes, modal appearances.
  static Future<void> medium() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Signature heavy impact for milestone completions and critical actions.
  static Future<void> heavy() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  /// Success sequence for Perfect Day achievements and commitment submissions.
  static Future<void> success() async {
    try {
      await HapticFeedback.lightImpact();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Warning sequence for approaching deadlines or consequence triggers.
  static Future<void> warning() async {
    try {
      await HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }
}
