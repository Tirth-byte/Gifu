import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum StatusChipType { primary, success, warning, destructive, neutral }

/// Compact status chip for commitment statuses, streaks, and proof badges.
class StatusChip extends StatelessWidget {
  final String label;
  final StatusChipType type;
  final Widget? icon;

  const StatusChip({
    super.key,
    required this.label,
    this.type = StatusChipType.primary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bgColor, Color textColor, Color borderColor) = switch (type) {
      StatusChipType.primary => (
        AppColors.primarySubtle,
        AppColors.primaryLight,
        const Color(0x33787DCC),
      ),
      StatusChipType.success => (
        AppColors.successSubtle,
        AppColors.success,
        const Color(0x3334D399),
      ),
      StatusChipType.warning => (
        AppColors.warningSubtle,
        AppColors.warning,
        const Color(0x33FBBF24),
      ),
      StatusChipType.destructive => (
        AppColors.destructiveSubtle,
        AppColors.destructive,
        const Color(0x33F87171),
      ),
      StatusChipType.neutral => (
        AppColors.surfaceElevated,
        AppColors.textSecondary,
        AppColors.borderMedium,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadii.full),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: AppSpacing.xs)],
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
