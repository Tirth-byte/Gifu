import 'package:flutter/material.dart';

import '../theme/app_typography.dart';

/// Reusable avatar widget that renders an image if photoUrl is available,
/// gracefully falling back to initials if photoUrl is null/empty or on network error.
class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String fallbackInitial;
  final double size;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final TextStyle? textStyle;

  const UserAvatar({
    super.key,
    required this.photoUrl,
    required this.fallbackInitial,
    this.size = 36,
    this.backgroundColor = const Color(0xFFF1F5F9),
    this.borderColor = const Color(0xFFE2E8F0),
    this.borderWidth = 1.5,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final validUrl = photoUrl?.trim();
    final hasUrl = validUrl != null && validUrl.isNotEmpty;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      alignment: Alignment.center,
      child: hasUrl
          ? Image.network(
              validUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildFallback(),
            )
          : _buildFallback(),
    );
  }

  Widget _buildFallback() {
    final initial = fallbackInitial.trim().isNotEmpty
        ? fallbackInitial.trim()[0].toUpperCase()
        : '?';

    return Center(
      child: Text(
        initial,
        style:
            textStyle ??
            AppTypography.inter(
              fontSize: size * 0.38,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
      ),
    );
  }
}
