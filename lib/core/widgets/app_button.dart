import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../haptics/app_haptics.dart';
import '../motion/app_motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum AppButtonVariant { primary, secondary, ghost, destructive }

enum AppButtonSize { sm, md, lg }

/// Tactile, accessible, high-craft button component for Gufi.
class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final Widget? icon;
  final bool isFullWidth;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.md,
    this.isLoading = false,
    this.icon,
    this.isFullWidth = false,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  void _handleTapDown(TapDownDetails _) {
    if (!_isEnabled) return;
    setState(() => _isPressed = true);
    AppHaptics.light();
  }

  void _handleTapUp(TapUpDetails _) {
    if (_isPressed) setState(() => _isPressed = false);
  }

  void _handleTapCancel() {
    if (_isPressed) setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final double height = switch (widget.size) {
      AppButtonSize.sm => 36.0,
      AppButtonSize.md => 48.0,
      AppButtonSize.lg => 56.0,
    };

    final EdgeInsetsGeometry padding = switch (widget.size) {
      AppButtonSize.sm => const EdgeInsets.symmetric(horizontal: 14),
      AppButtonSize.md => const EdgeInsets.symmetric(horizontal: 20),
      AppButtonSize.lg => const EdgeInsets.symmetric(horizontal: 24),
    };

    final TextStyle textStyle = switch (widget.size) {
      AppButtonSize.sm => AppTypography.buttonSmall,
      AppButtonSize.md => AppTypography.button,
      AppButtonSize.lg => AppTypography.button.copyWith(fontSize: 16),
    };

    final Color bgColor;
    final Color textColor;
    final Border? border;

    switch (widget.variant) {
      case AppButtonVariant.primary:
        bgColor = _isEnabled ? AppColors.primary : AppColors.surfaceInteractive;
        textColor = _isEnabled ? Colors.white : AppColors.textDisabled;
        border = null;
      case AppButtonVariant.secondary:
        bgColor = _isEnabled ? AppColors.surfaceElevated : AppColors.surface;
        textColor = _isEnabled ? AppColors.textPrimary : AppColors.textDisabled;
        border = Border.all(
          color: _isEnabled ? AppColors.borderMedium : AppColors.borderSubtle,
          width: 1,
        );
      case AppButtonVariant.ghost:
        bgColor = Colors.transparent;
        textColor = _isEnabled ? AppColors.textPrimary : AppColors.textDisabled;
        border = null;
      case AppButtonVariant.destructive:
        bgColor = _isEnabled ? AppColors.destructiveSubtle : AppColors.surface;
        textColor = _isEnabled ? AppColors.destructive : AppColors.textDisabled;
        border = Border.all(
          color: _isEnabled ? const Color(0x3DF87171) : AppColors.borderSubtle,
          width: 1,
        );
    }

    Widget content = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading) ...[
          SizedBox.square(
            dimension: 16,
            child: CupertinoActivityIndicator(radius: 8, color: textColor),
          ),
          const SizedBox(width: AppSpacing.sm),
        ] else if (widget.icon != null) ...[
          widget.icon!,
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(widget.text, style: textStyle.copyWith(color: textColor)),
      ],
    );

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: _isEnabled ? widget.onPressed : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? AppMotion.pressScale : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.snappy,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppRadii.full),
            border: border,
            boxShadow: widget.variant == AppButtonVariant.primary && _isEnabled
                ? const [
                    BoxShadow(
                      color: Color(0x33787DCC),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: content,
        ),
      ),
    );
  }
}
