import 'package:flutter/material.dart';

import '../haptics/app_haptics.dart';
import '../motion/app_motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// High-performance opaque surface card for standard content items.
/// Avoids heavy full-screen blurs to guarantee 120Hz frame pacing.
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.borderRadius = AppRadii.lgBorder,
    this.backgroundColor = AppColors.surface,
    this.borderColor = AppColors.borderSubtle,
    this.onTap,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    setState(() => _isPressed = true);
    AppHaptics.selection();
  }

  void _handleTapUp(TapUpDetails _) {
    if (_isPressed) setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (_isPressed) setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      margin: widget.margin,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: widget.borderRadius,
        border: Border.all(color: widget.borderColor, width: 1.0),
      ),
      child: widget.child,
    );

    if (widget.onTap == null) {
      return card;
    }

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? AppMotion.pressScale : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.snappy,
        child: card,
      ),
    );
  }
}
