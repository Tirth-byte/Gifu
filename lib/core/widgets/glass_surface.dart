import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Selective liquid-glass surface for floating navigation, sheets, and controls.
/// Wrapped in a [RepaintBoundary] to preserve 120Hz frame pacing.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double blur;
  final Color backgroundColor;
  final BoxBorder? border;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? shadows;

  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = AppRadii.xlBorder,
    this.blur = 18.0,
    this.backgroundColor = AppColors.glassBackground,
    this.border,
    this.padding,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow:
              shadows ??
              const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: borderRadius,
                border:
                    border ??
                    Border.all(color: AppColors.glassBorder, width: 1.0),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
