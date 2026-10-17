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

    return Semantics(
      label: 'Account menu',
      button: true,
      child: GestureDetector(
        onTap: () {
          AppHaptics.selection();
          _showAccountBottomSheet(context, profile);
        },
        behavior: HitTestBehavior.opaque,
        child: UserAvatar(
          photoUrl: profile?.profilePhotoUrl,
          fallbackInitial: initial,
          size: 36,
          backgroundColor: const Color(0xFFF1F5F9),
          borderColor: const Color(0xFFE2E8F0),
          borderWidth: 1.5,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            letterSpacing: -0.2,
          ),
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            MediaQuery.of(modalContext).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Subtle handle bar
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Avatar circle
              UserAvatar(
                photoUrl: profile?.profilePhotoUrl,
                fallbackInitial: initial,
                size: 60,
                backgroundColor: const Color(0xFFF1F5F9),
                borderColor: const Color(0xFFE2E8F0),
                borderWidth: 2,
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),

              // Display Name
              Text(
                displayName,
                style: const TextStyle(
                  fontFamily: 'Gambarino',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),

              // Username
              if (username.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '@$username',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],

              // Email if distinct
              if (email.isNotEmpty && email != username) ...[
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],

              const SizedBox(height: 28),
              const Divider(color: Color(0xFFF1F5F9), height: 1),
              const SizedBox(height: 16),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    AppHaptics.medium();
                    Navigator.of(modalContext).pop();

                    // Perform complete sign out
                    await SupabaseAuthRepository.instance.signOut();

                    if (context.mounted) {
                      context.go('/auth');
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFFCA5A5), width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: Color(0xFFEF4444),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Log out',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
