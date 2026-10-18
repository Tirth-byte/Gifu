import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/services/app_preferences_service.dart';
import '../features/admin/presentation/admin_dashboard_page.dart';
import '../features/auth/data/repositories/supabase_auth_repository.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/circles/data/repositories/supabase_circle_repository.dart';
import '../features/circles/domain/models/circle.dart';
import '../features/circles/presentation/circle_create_page.dart';
import '../features/circles/presentation/circle_entry_page.dart';
import '../features/circles/presentation/circle_invite_page.dart';
import '../features/circles/presentation/circle_join_page.dart';
import '../features/today/presentation/today_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/onboarding/presentation/screens/bootstrap_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_screen_2.dart';

/// Module-level accessor to the single shared auth repository.
/// Used by route guards outside Riverpod scope.
final _sharedAuthRepo = SupabaseAuthRepository.instance;
final _sharedCircleRepo = SupabaseCircleRepository.instance;

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Session restore rule:
/// PROFILE INCOMPLETE -> profile setup (/auth)
/// PROFILE COMPLETE + NO CIRCLES -> Circle Entry (/circle-entry)
/// PROFILE COMPLETE + HAS CIRCLE(S), BUT NO CIRCLE HAS >= 2 ACTIVE MEMBERS -> pending creator invite/waiting state
/// PROFILE COMPLETE + AT LEAST ONE CIRCLE WITH >= 2 ACTIVE MEMBERS -> Today (/today)
/// If Circle A has 1 active member, but Circle B has 4 active members -> Today (/today)
Future<String?> _resolveUserLandingRoute() async {
  final currentProfile =
      _sharedAuthRepo.currentUserProfile ??
      await _sharedAuthRepo.restoreSession();
  if (currentProfile == null) return null;
  if (currentProfile.isAdmin) return '/admin';
  if (!currentProfile.onboardingCompleted) return '/auth';

  final circles = await _sharedCircleRepo.getUserCircles(currentProfile.id);
  if (circles.isEmpty) {
    return '/circle-entry';
  }

  // Check if at least ONE circle has >= 2 active members
  Circle? pendingCircleWithOneMember;
  for (final circle in circles) {
    final members = await _sharedCircleRepo.getCircleMembers(circle.id);
    final activeCount = members.where((m) => m.isActive).length;
    if (activeCount >= 2) {
      return '/today';
    }
    pendingCircleWithOneMember ??= circle;
  }

  // No circle has >= 2 active members!
  // Route to the pending creator invite/waiting state
  if (pendingCircleWithOneMember != null) {
    return '/circle-invite/${pendingCircleWithOneMember.id}';
  }

  return '/circle-entry';
}

/// Central Gufi router with protected routes and circle membership prerequisite checks.
GoRouter createAppRouter({
  String initialLocation = '/',
  GlobalKey<NavigatorState>? navigatorKey,
}) => GoRouter(
  navigatorKey: navigatorKey ?? _rootNavigatorKey,
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) async {
        final profile =
            _sharedAuthRepo.currentUserProfile ??
            await _sharedAuthRepo.restoreSession();

        // 1. Check Supabase authenticated session FIRST.
        // 2. If NO valid authenticated session exists: ALWAYS start at Onboarding Screen 1.
        if (profile == null) {
          return null;
        }

        // 3. If a valid authenticated session DOES exist: resolve authenticated destination.
        return await _resolveUserLandingRoute();
      },
      builder: (context, state) => const OnboardingPage(),
    ),
    GoRoute(
      path: '/bootstrap',
      builder: (context, state) => const BootstrapScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingPage(),
    ),
    GoRoute(
      path: '/auth',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const AuthPage(),
        transitionDuration: const Duration(milliseconds: 190),
        reverseTransitionDuration: const Duration(milliseconds: 170),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.025, 0.0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    ),
    GoRoute(
      path: '/screen-2',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const OnboardingScreen2(),
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.035, 0.0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    ),
    GoRoute(
      path: '/circle-entry',
      redirect: (context, state) async {
        final destination = await _resolveUserLandingRoute();
        if (destination != null && destination != '/circle-entry') {
          return destination;
        }
        return null;
      },
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const CircleEntryPage(),
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.025, 0.0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    ),
    GoRoute(
      path: '/circle-create',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const CircleCreatePage(),
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.035, 0.0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    ),
    GoRoute(
      path: '/circle-invite/:circleId',
      pageBuilder: (context, state) {
        final circleId = state.pathParameters['circleId'] ?? '';
        return CustomTransitionPage(
          key: state.pageKey,
          child: CircleInvitePage(circleId: circleId),
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.035, 0.0),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(opacity: curved, child: child),
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/circle-join',
      redirect: (context, state) async {
        final profile =
            _sharedAuthRepo.currentUserProfile ??
            await _sharedAuthRepo.restoreSession();
        if (profile == null) {
          final code =
              state.uri.queryParameters['code'] ?? (state.extra as String?);
          if (code != null && code.isNotEmpty) {
            await AppPreferencesService.instance.setPendingInviteCode(code);
          }
          return '/auth';
        }
        return null;
      },
      pageBuilder: (context, state) {
        final code =
            state.uri.queryParameters['code'] ?? (state.extra as String?);
        return CustomTransitionPage(
          key: state.pageKey,
          child: CircleJoinPage(initialCode: code),
          transitionDuration: const Duration(milliseconds: 200),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.035, 0.0),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(opacity: curved, child: child),
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/join',
      redirect: (context, state) {
        final code = state.uri.queryParameters['code'];
        if (code != null && code.isNotEmpty) {
          return '/circle-join?code=$code';
        }
        return '/circle-join';
      },
    ),
    GoRoute(
      path: '/join/:code',
      redirect: (context, state) {
        final code = state.pathParameters['code'];
        return '/circle-join?code=$code';
      },
    ),
    GoRoute(
      path: '/auth-confirm',
      redirect: (context, state) async {
        // Wait briefly to allow Supabase deep-link session processing
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final destination = await _resolveUserLandingRoute();
        return destination ?? '/auth';
      },
    ),
    GoRoute(
      path: '/reset-callback',
      redirect: (context, state) async {
        // Wait briefly to allow Supabase recovery session processing
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return '/auth';
      },
    ),
    GoRoute(
      path: '/today',
      redirect: (context, state) async {
        final destination = await _resolveUserLandingRoute();
        if (destination != null && destination != '/today') {
          return destination;
        }
        return null;
      },
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const TodayPage(),
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.025, 0.0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    ),
    GoRoute(
      path: '/admin',
      redirect: (context, state) async {
        // Protected Admin route guard: verify admin authorization.
        final currentProfile =
            _sharedAuthRepo.currentUserProfile ??
            await _sharedAuthRepo.restoreSession();
        if (currentProfile != null && !currentProfile.isAdmin) {
          final circles = await _sharedCircleRepo.getUserCircles(
            currentProfile.id,
          );
          if (circles.isEmpty) {
            return '/circle-entry';
          }
          return '/today';
        }
        return null;
      },
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const AdminDashboardPage(),
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.025, 0.0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      ),
    ),
  ],
);

final GoRouter appRouter = createAppRouter();
