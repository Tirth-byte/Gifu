import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/repositories/supabase_auth_repository.dart';
import '../../features/auth/domain/models/user_profile.dart';
import '../haptics/app_haptics.dart';
import 'user_avatar.dart';

/// Restrained top-right account action button for authenticated screens.
class AccountActionButton extends StatefulWidget {
  const AccountActionButton({super.key});

  @override
  State<AccountActionButton> createState() => _AccountActionButtonState();
}

class _AccountActionButtonState extends State<AccountActionButton> {
  StreamSubscription<UserProfile?>? _authSub;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _profile = SupabaseAuthRepository.instance.currentUserProfile;
    _authSub = SupabaseAuthRepository.instance.authStateChanges.listen((p) {
      if (mounted) {
        setState(() => _profile = p);
      }
    });

    // Proactively refresh if avatar might have been updated during onboarding
    if (_profile == null || _profile?.profilePhotoUrl == null) {
      SupabaseAuthRepository.instance
          .fetchCurrentProfile(forceRefresh: true)
          .then((fresh) {
            if (mounted && fresh != null) {
              setState(() => _profile = fresh);
            }
          })
          .catchError((_) {});
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile =
        _profile ?? SupabaseAuthRepository.instance.currentUserProfile;
    final initial = _getInitial(profile);
    final displayName = (profile?.displayName?.trim().isNotEmpty ?? false)
        ? profile!.displayName!.trim()
        : (profile?.username.isNotEmpty ?? false)
        ? profile!.username
        : 'Account';

    return Semantics(
      label: 'Account menu',
      button: true,
      child: GestureDetector(
        onTap: () {
          AppHaptics.selection();
          _showAccountBottomSheet(context, profile);
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 54,
          padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8EEF5), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3365).withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildChipAvatar(profile?.profilePhotoUrl, initial),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 85),
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3365),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChipAvatar(String? photoUrl, String initial) {
    final validUrl = photoUrl?.trim();
    final hasUrl = validUrl != null && validUrl.isNotEmpty;

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: const Color(0xFFF1F5F9),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasUrl
          ? Image.network(
              validUrl,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildFallbackInitial(initial),
            )
          : _buildFallbackInitial(initial),
    );
  }

  Widget _buildFallbackInitial(String initial) {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1E3365),
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  String _getInitial(UserProfile? profile) {
    if (profile == null) return '?';
    if (profile.displayName != null && profile.displayName!.trim().isNotEmpty) {
      return profile.displayName!.trim()[0].toUpperCase();
    }
    if (profile.username.trim().isNotEmpty) {
      return profile.username.trim()[0].toUpperCase();
    }
    if (profile.email.trim().isNotEmpty) {
      return profile.email.trim()[0].toUpperCase();
    }
    return '?';
  }

  void _showAccountBottomSheet(BuildContext context, UserProfile? profile) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      isScrollControlled: true,
      builder: (modalContext) {
        final initial = _getInitial(profile);
        final displayName = (profile?.displayName?.trim().isNotEmpty ?? false)
            ? profile!.displayName!.trim()
            : (profile?.username.isNotEmpty ?? false)
            ? profile!.username
            : 'Account';
        final username = profile?.username ?? '';
        final email = profile?.email ?? '';

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalContext).size.height * 0.88,
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 13, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Subtle drag handle
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Profile Hero Avatar
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E3365)
                                .withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFFD3E4F8),
                            width: 1.5,
                          ),
                        ),
                        child: UserAvatar(
                          photoUrl: profile?.profilePhotoUrl,
                          fallbackInitial: initial,
                          size: 88,
                          backgroundColor: const Color(0xFFF1F5F9),
                          borderColor: Colors.transparent,
                          borderWidth: 0,
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E3365),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Display Name
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontFamily: 'Gambarino',
                        fontSize: 31,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3365),
                        letterSpacing: -0.4,
                        height: 1.15,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Username
                    if (username.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '@$username',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF7C8AA5),
                          letterSpacing: -0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    // Email
                    if (email.isNotEmpty && email != username) ...[
                      const SizedBox(height: 5),
                      Text(
                        email,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14.5,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF94A3B8),
                          letterSpacing: -0.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Action Group Container
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFFE8EEF5),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E3365)
                                .withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _buildActionItem(
                            icon: Icons.person_outline_rounded,
                            title: 'View profile',
                            subtitle: 'See your profile.',
                            onTap: () =>
                                _handleActionTap(modalContext, 'View profile'),
                          ),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            indent: 74,
                            endIndent: 16,
                            color: Color(0xFFF1F5F9),
                          ),
                          _buildActionItem(
                            icon: Icons.edit_outlined,
                            title: 'Edit profile',
                            subtitle: 'Update your name, photo and details.',
                            onTap: () =>
                                _handleActionTap(modalContext, 'Edit profile'),
                          ),
                          const Divider(
                            height: 1,
                            thickness: 1,
                            indent: 74,
                            endIndent: 16,
                            color: Color(0xFFF1F5F9),
                          ),
                          _buildActionItem(
                            icon: Icons.settings_outlined,
                            title: 'Account settings',
                            subtitle: 'Manage account preferences.',
                            onTap: () => _handleActionTap(
                              modalContext,
                              'Account settings',
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Refined Secondary Logout Card
                    _InteractiveRow(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () async {
                        AppHaptics.medium();
                        Navigator.of(modalContext).pop();

                        await SupabaseAuthRepository.instance.signOut();

                        if (context.mounted) {
                          context.go('/auth');
                        }
                      },
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 66),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7F7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFECACA),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFFEE2E2),
                              ),
                              child: const Icon(
                                Icons.logout_rounded,
                                size: 21,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                            SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Log out',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFDC2626),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Sign out of your account.',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFFA57C7C),
                                      letterSpacing: -0.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: Color(0xFFFCA5A5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return _InteractiveRow(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFF4F8FD),
              ),
              child: Icon(icon, size: 21, color: const Color(0xFF1E3365)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E3365),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF7C8AA5),
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  void _handleActionTap(BuildContext modalContext, String actionName) {
    AppHaptics.selection();
    Navigator.of(modalContext).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$actionName will be available soon',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        duration: const Duration(milliseconds: 1800),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Interactive row wrapper providing subtle 100ms press feedback.
class _InteractiveRow extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius? borderRadius;

  const _InteractiveRow({
    required this.child,
    required this.onTap,
    this.borderRadius,
  });

  @override
  State<_InteractiveRow> createState() => _InteractiveRowState();
}

class _InteractiveRowState extends State<_InteractiveRow> {
  bool _isDown = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isDown = true),
      onTapUp: (_) => setState(() => _isDown = false),
      onTapCancel: () => setState(() => _isDown = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isDown ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _isDown ? 0.8 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}
