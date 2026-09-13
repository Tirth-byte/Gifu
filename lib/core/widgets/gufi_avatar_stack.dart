import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'gufi_avatar.dart';

/// Data representation for an individual member in a Gufi avatar stack.
class GufiAvatarItem {
  final String name;
  final String? imageUrl;
  final String? initials;
  final Color? accentColor;

  const GufiAvatarItem({
    required this.name,
    this.imageUrl,
    this.initials,
    this.accentColor,
  });
}

/// Variable-length avatar stack for Gufi Circles.
///
/// Designed to scale gracefully from 2 members to 15+ members.
/// Never assumes a fixed 3-person group size.
/// When member count exceeds [maxVisible], renders an overflow pill/badge (+N).
class GufiAvatarStack extends StatelessWidget {
  final List<GufiAvatarItem> items;
  final int maxVisible;
  final double size;
  final double overlap;
  final Color ringColor;

  const GufiAvatarStack({
    super.key,
    required this.items,
    this.maxVisible = 3,
    this.size = 34.0,
    this.overlap = 10.0,
    this.ringColor = AppColors.background,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final int total = items.length;
    final bool hasOverflow = total > maxVisible;
    final int visibleCount = hasOverflow ? maxVisible : total;
    final int overflowCount = total - visibleCount;

    final double step = size - overlap;
    final int totalRenders = visibleCount + (hasOverflow ? 1 : 0);
    final double totalWidth = size + ((totalRenders - 1) * step);

    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(
        children: [
          for (int i = 0; i < visibleCount; i++)
            Positioned(
              left: i * step,
              child: GufiAvatar(
                name: items[i].name,
                imageUrl: items[i].imageUrl,
                initials: items[i].initials,
                size: size,
                borderColor: ringColor,
                borderWidth: 2.0,
                backgroundColor:
                    items[i].accentColor ?? AppColors.surfaceElevated,
              ),
            ),
          if (hasOverflow)
            Positioned(
              left: visibleCount * step,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppColors.surfaceInteractive,
                  shape: BoxShape.circle,
                  border: Border.all(color: ringColor, width: 2.0),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$overflowCount',
                  style: AppTypography.micro.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
