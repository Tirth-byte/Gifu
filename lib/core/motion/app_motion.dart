import 'package:flutter/material.dart';

import '../haptics/app_haptics.dart';

/// Centralized motion tokens and interactive press behavior for Gufi.
/// Built for 120Hz frame pacing with subtle tactile transitions.
class AppMotion {
  AppMotion._();

  // Semantic Durations
  static const Duration micro = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 280);
  static const Duration expressive = Duration(milliseconds: 500);

  // Curves
  static const Curve snappy = Curves.easeOutCubic;
  static const Curve soft = Curves.easeInOutCubic;
  static const Curve expressiveCurve = Curves.fastLinearToSlowEaseIn;

  // Press Scale Constants
  static const double pressScale = 0.975;
  static const double iconPressScale = 0.95;
}

/// Tactile interactive wrapper providing subtle scaling (1.00 -> 0.975 -> 1.00)
/// and optional haptic feedback on tap without bouncy physics.
class AppPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final bool enableHaptic;
  final HitTestBehavior behavior;

  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = AppMotion.pressScale,
    this.enableHaptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    setState(() => _isPressed = true);
    if (widget.enableHaptic) {
      AppHaptics.selection();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveChild = AnimatedScale(
      scale: _isPressed ? widget.scaleFactor : 1.0,
      duration: AppMotion.fast,
      curve: AppMotion.snappy,
      child: widget.child,
    );

    if (widget.onTap == null) {
      return widget.child;
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: effectiveChild,
    );
  }
}
