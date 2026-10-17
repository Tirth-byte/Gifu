import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/app_preferences_service.dart';
import '../../../../core/services/gufi_backend_store.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/data/repositories/supabase_auth_repository.dart';
import '../../../circles/data/repositories/supabase_circle_repository.dart';
import '../../../circles/domain/models/circle.dart';

/// Authoritative App Bootstrap Screen.
///
/// Ensures zero UI flicker during launch:
/// 1. Holds a clean, pure white canvas (#FFFFFF) with subtle Gufi wordmark.
/// 2. Restores persistent Supabase auth session from local disk.
/// 3. Resolves the authoritative logical destination before navigating.
///
/// Routing Rules:
/// - NO SESSION & !hasSeenIntro  -> /onboarding
/// - NO SESSION & hasSeenIntro   -> /auth
/// - SESSION & ADMIN            -> /admin
/// - SESSION & INCOMPLETE        -> /auth
/// - SESSION & PENDING DEEP LINK -> /circle-join?code=...
/// - SESSION & NO CIRCLES        -> /circle-entry
/// - SESSION & CIRCLE < 2 MEMB   -> /circle-invite/:id
/// - SESSION & CIRCLE >= 2 MEMB  -> /today
class BootstrapScreen extends StatefulWidget {
  const BootstrapScreen({super.key});

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveDestination();
    });
  }

  Future<void> _resolveDestination() async {
    try {
      // 1. Initialize persistent storage services
      await AppPreferencesService.instance.init();
      await GufiBackendStore.instance.init();

      // 2. Check for pending deep-link invite code
      final pendingInvite = AppPreferencesService.instance
          .getPendingInviteCode();

      // 3. Restore persisted authentication session
      final profile = await SupabaseAuthRepository.instance.restoreSession();

      if (!mounted) return;

      // 4. Unauthenticated user
      if (profile == null) {
        final hasSeenIntro = AppPreferencesService.instance.getHasSeenIntro();
        if (hasSeenIntro) {
          context.go('/auth');
        } else {
          context.go('/onboarding');
        }
        return;
      }

      // 5. Admin user
      if (profile.isAdmin) {
        context.go('/admin');
        return;
      }

      // 6. Incomplete profile setup
      if (!profile.onboardingCompleted) {
        context.go('/auth');
        return;
      }

      // 7. If user clicked a deep link invite before or during auth
      if (pendingInvite != null && pendingInvite.isNotEmpty) {
        await AppPreferencesService.instance.clearPendingInviteCode();
        if (!mounted) return;
        context.go('/circle-join?code=$pendingInvite');
        return;
      }

      // 8. Fetch active Circle memberships
      final circles = await SupabaseCircleRepository.instance.getUserCircles(
        profile.id,
      );

      if (!mounted) return;

      if (circles.isEmpty) {
        context.go('/circle-entry');
        return;
      }

      // 9. Check if at least one circle has >= 2 active members
      Circle? pendingCircleWithOneMember;
      for (final circle in circles) {
        final members = await SupabaseCircleRepository.instance
            .getCircleMembers(circle.id);
        if (!mounted) return;
        final activeCount = members.where((m) => m.isActive).length;
        if (activeCount >= 2) {
          context.go('/today');
          return;
        }
        pendingCircleWithOneMember ??= circle;
      }

      // 10. Circle created, waiting for teammate
      if (pendingCircleWithOneMember != null) {
        context.go('/circle-invite/${pendingCircleWithOneMember.id}');
      } else {
        context.go('/circle-entry');
      }
    } catch (e) {
      debugPrint('Error resolving app bootstrap: $e');
      if (mounted) {
        context.go('/auth');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          'Gufi',
          style: TextStyle(
            fontFamily: AppTypography.gambarinoFontFamily,
            fontSize: 32,
            fontWeight: FontWeight.w400,
            color: Color(0xFF1E3365),
            letterSpacing: -0.6,
          ),
        ),
      ),
    );
  }
}
