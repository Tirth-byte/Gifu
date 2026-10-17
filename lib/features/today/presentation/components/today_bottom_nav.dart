import 'package:flutter/material.dart';

import '../../../../core/haptics/app_haptics.dart';
import '../../../../core/theme/app_typography.dart';

/// Restrained Gufi bottom navigation bar.
/// Exactly 4 tabs: Today, Friends, Activity, Profile.
/// No floating glass bar, no giant shadows.
/// Simple icons, small crisp labels, Gufi navy/blue active state.
class TodayBottomNav extends StatelessWidget {
  const TodayBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const Color gufiNavy = Color(0xFF1E3365);
  static const Color primaryBlue = Color(0xFF5880DA);
  static const Color inactiveMuted = Color(0xFF8E9EAB);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: gufiNavy.withValues(alpha: 0.08), width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.calendar_today_rounded,
                label: 'Today',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.group_outlined,
                label: 'Friends',
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.show_chart_rounded,
                label: 'Activity',
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.person_outline_rounded,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = currentIndex == index;

    return InkWell(
      onTap: () {
        if (!isSelected) {
          AppHaptics.selection();
          onTap(index);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? primaryBlue : inactiveMuted,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? primaryBlue : inactiveMuted,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
