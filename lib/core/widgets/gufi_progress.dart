import 'package:flutter/material.dart';

import '../motion/app_motion.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Minimal, high-craft progress indicator for commitments and weekly streaks.
class GufiProgress extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final double height;
  final Color? progressColor;
  final Color? trackColor;

  const GufiProgress({
    super.key,
    required this.value,
    this.height = 6.0,
    this.progressColor,
    this.trackColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveValue = value.clamp(0.0, 1.0);
    final effectiveProgressColor = progressColor ?? AppColors.primary;
    final effectiveTrackColor = trackColor ?? AppColors.surfaceInteractive;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: effectiveTrackColor,
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final targetWidth = constraints.maxWidth * effectiveValue;
          return Stack(
            children: [
              AnimatedContainer(
                duration: AppMotion.standard,
                curve: AppMotion.snappy,
                width: targetWidth,
                height: height,
                decoration: BoxDecoration(
                  color: effectiveProgressColor,
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
