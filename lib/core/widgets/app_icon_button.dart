import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../haptics/app_haptics.dart';
import '../motion/app_motion.dart';
import '../theme/app_colors.dart';

enum AppIconButtonVariant { surface, ghost, primary, glass }

/// Tactile icon button component utilizing HugeIcons.
class AppIconButton extends StatefulWidget {
  final List<List<dynamic>> icon;
  final VoidCallback? onPressed;
  final AppIconButtonVariant variant;
  final double size;
  final double iconSize;
  final Color? color;
  final String? tooltip;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.variant = AppIconButtonVariant.surface,
    this.size = 44.0,
    this.iconSize = 22.0,
    this.color,
    this.tooltip,
  });

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null;

  void _handleTapDown(TapDownDetails _) {
    if (!_isEnabled) return;
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
    final Color bgColor;
    final Color iconColor;
    final Border? border;

    switch (widget.variant) {
      case AppIconButtonVariant.surface:
        bgColor = _isEnabled ? AppColors.surfaceElevated : AppColors.surface;
        iconColor =
            widget.color ??
            (_isEnabled ? AppColors.textPrimary : AppColors.textDisabled);
        border = Border.all(
          color: _isEnabled ? AppColors.borderMedium : AppColors.borderSubtle,
          width: 1,
        );
      case AppIconButtonVariant.ghost:
        bgColor = Colors.transparent;
        iconColor =
            widget.color ??
            (_isEnabled ? AppColors.textPrimary : AppColors.textDisabled);
        border = null;
      case AppIconButtonVariant.primary:
        bgColor = _isEnabled ? AppColors.primary : AppColors.surfaceInteractive;
        iconColor = Colors.white;
        border = null;
      case AppIconButtonVariant.glass:
        bgColor = AppColors.glassBackground;
        iconColor = widget.color ?? AppColors.textPrimary;
        border = Border.all(color: AppColors.glassBorder, width: 1);
    }

    Widget button = GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _isEnabled ? widget.onPressed : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? AppMotion.iconPressScale : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.snappy,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: border,
          ),
          alignment: Alignment.center,
          child: HugeIcon(
            icon: widget.icon,
            color: iconColor,
            size: widget.iconSize,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }
}
