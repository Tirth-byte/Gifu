import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../auth/domain/models/user_profile.dart';

/// Top bar for Gufi Today:
/// Left: "Gufi" in Gambarino (28–32px, Gufi navy #1E3365)
/// Right: Circular profile avatar (40–44px)
/// No dead search button.
class TodayTopBar extends StatelessWidget {
  const TodayTopBar({super.key, required this.user, this.onAvatarTap});

  final UserProfile? user;
  final VoidCallback? onAvatarTap;

  static const Color gufiNavy = Color(0xFF1E3365);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Gambarino Gufi Wordmark
          Text(
            'Gufi',
            style: TextStyle(
              fontFamily: AppTypography.gambarinoFontFamily,
              fontSize: 30,
              fontWeight: FontWeight.w400,
              color: gufiNavy,
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),

          // User Profile Avatar
          GestureDetector(onTap: onAvatarTap, child: _buildAvatar()),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final avatarUrl = user?.profilePhotoUrl;
    final displayName = user?.displayName?.trim() ?? '';
    final username = user?.username.trim() ?? '';
    final initial = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : (username.isNotEmpty ? username[0].toUpperCase() : 'G');

    return UserAvatar(
      photoUrl: avatarUrl,
      fallbackInitial: initial,
      size: 42,
      backgroundColor: const Color(0xFFBCDBFA),
      borderColor: const Color(0xFF1E3365).withValues(alpha: 0.12),
      borderWidth: 1.5,
      textStyle: AppTypography.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: gufiNavy,
      ),
    );
  }
}
