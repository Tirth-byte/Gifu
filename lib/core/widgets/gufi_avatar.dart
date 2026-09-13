import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Clean circular avatar with image support and initials fallback.
class GufiAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final String? initials;
  final double size;
  final Color borderColor;
  final double borderWidth;
  final Color? backgroundColor;

  const GufiAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.initials,
    this.size = 36.0,
    this.borderColor = AppColors.borderSubtle,
    this.borderWidth = 1.5,
    this.backgroundColor,
  });

  String get _computedInitials {
    if (initials != null && initials!.isNotEmpty) {
      return initials!;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'G';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final double innerSize = size - (borderWidth * 2);
    final effectiveBg = backgroundColor ?? AppColors.surfaceElevated;

    Widget avatarContent;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatarContent = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: innerSize,
        height: innerSize,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: effectiveBg,
          alignment: Alignment.center,
          child: Text(
            _computedInitials,
            style: AppTypography.caption.copyWith(
              fontSize: size * 0.38,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: effectiveBg,
          alignment: Alignment.center,
          child: Text(
            _computedInitials,
            style: AppTypography.caption.copyWith(
              fontSize: size * 0.38,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    } else {
      avatarContent = Container(
        color: effectiveBg,
        alignment: Alignment.center,
        child: Text(
          _computedInitials,
          style: AppTypography.caption.copyWith(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: ClipOval(child: avatarContent),
    );
  }
}
