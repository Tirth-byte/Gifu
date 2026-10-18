import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/app/router.dart';
import 'package:gufi/core/services/app_preferences_service.dart';
import 'package:gufi/core/services/gufi_backend_store.dart';
import 'package:gufi/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:gufi/features/auth/domain/models/user_profile.dart';
import 'package:gufi/features/auth/presentation/auth_page.dart';
import 'package:gufi/features/circles/presentation/circle_entry_page.dart';
import 'package:gufi/features/onboarding/presentation/components/circular_arrow_button.dart';
import 'package:gufi/features/onboarding/presentation/onboarding_page.dart';
import 'package:gufi/features/onboarding/presentation/screens/onboarding_screen_2.dart';
import 'package:gufi/features/today/presentation/today_page.dart';

void main() {
  final store = GufiBackendStore.instance;
  final authRepo = SupabaseAuthRepository.instance;

  setUp(() async {
    store.reset();
    AppPreferencesService.instance.resetForTesting();
    await AppPreferencesService.instance.init();
    authRepo.setSessionForTesting(null);
  });

  UserProfile makeProfile({
    String id = 'usr-test-1',
    String username = 'testuser',
    bool onboardingCompleted = true,
    bool isAdmin = false,
  }) {
    final now = DateTime.utc(2026, 10, 18);
    return UserProfile(
      id: id,
      email: '$username@gufi.app',
      emailNormalized: '$username@gufi.app',
      emailVerified: true,
      username: username,
      usernameNormalized: username,
      displayName: 'Test User',
      onboardingCompleted: onboardingCompleted,
      role: isAdmin ? 'admin' : 'user',
      createdAt: now,
      updatedAt: now,
    );
  }

  group('Startup / Onboarding State Machine Rules', () {
    testWidgets(
      'CASE 1: No Supabase session -> fresh cold launch starts at Screen 1',
      (WidgetTester tester) async {
        authRepo.setSessionForTesting(null);

        final router = createAppRouter(initialLocation: '/');
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingPage), findsOneWidget);
        expect(find.text('Commit.\nShow up.\nGrow together.'), findsOneWidget);
        expect(find.byType(CircularArrowButton), findsOneWidget);
        expect(find.byType(AuthPage), findsNothing);
      },
    );

    testWidgets(
      'CASE 2: No session -> Navigate Screen 1 -> Screen 2 -> Welcome -> Kill/restart -> Screen 1',
      (WidgetTester tester) async {
        authRepo.setSessionForTesting(null);

        // Run 1: Navigate to Welcome screen
        final router1 = createAppRouter(initialLocation: '/');
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router1)),
        );
        await tester.pumpAndSettle();

        // Screen 1 -> Screen 2
        await tester.tap(find.byType(CircularArrowButton));
        await tester.pumpAndSettle();
        expect(find.byType(OnboardingScreen2), findsOneWidget);

        // Screen 2 -> Welcome (/auth)
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.byType(AuthPage), findsOneWidget);
        expect(find.text('Welcome to Gufi'), findsOneWidget);

        // Simulate app kill and cold restart
        final router2 = createAppRouter(initialLocation: '/');
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router2)),
        );
        await tester.pumpAndSettle();

        // MUST be back at Onboarding Screen 1
        expect(find.byType(OnboardingPage), findsOneWidget);
        expect(find.text('Commit.\nShow up.\nGrow together.'), findsOneWidget);
        expect(find.byType(AuthPage), findsNothing);
      },
    );

    testWidgets(
      'CASE 3: No session -> Reach Login page -> Kill/restart -> Screen 1',
      (WidgetTester tester) async {
        authRepo.setSessionForTesting(null);

        // Run 1: Navigate to Login screen
        final router1 = createAppRouter(initialLocation: '/');
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router1)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(CircularArrowButton));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Log in'));
        await tester.pumpAndSettle();
        expect(find.byType(LoginEmailScreen), findsOneWidget);

        // Simulate kill & cold restart
        final router2 = createAppRouter(initialLocation: '/');
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router2)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingPage), findsOneWidget);
        expect(find.text('Commit.\nShow up.\nGrow together.'), findsOneWidget);
        expect(find.byType(LoginEmailScreen), findsNothing);
      },
    );

    testWidgets(
      'CASE 4: No session -> Reach Create Account page -> Kill/restart -> Screen 1',
      (WidgetTester tester) async {
        authRepo.setSessionForTesting(null);

        // Run 1: Navigate to Create Account
        final router1 = createAppRouter(initialLocation: '/');
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router1)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(CircularArrowButton));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Create an account'));
        await tester.pumpAndSettle();
        expect(find.byType(SignupEmailScreen), findsOneWidget);

        // Simulate kill & cold restart
        final router2 = createAppRouter(initialLocation: '/');
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router2)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingPage), findsOneWidget);
        expect(find.text('Commit.\nShow up.\nGrow together.'), findsOneWidget);
        expect(find.byType(SignupEmailScreen), findsNothing);
      },
    );

    testWidgets(
      'CASE 5: Authenticated session + incomplete profile -> Cold launch -> profile setup',
      (WidgetTester tester) async {
        final incompleteUser = makeProfile(
          id: 'usr-incomplete',
          username: '',
          onboardingCompleted: false,
        );
        authRepo.setSessionForTesting(incompleteUser);

        final router = createAppRouter(initialLocation: '/');
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router)),
        );
        await tester.pumpAndSettle();

        // Should bypass Onboarding Screen 1 and land on profile setup
        expect(find.byType(OnboardingPage), findsNothing);
        expect(find.byType(AuthPage), findsOneWidget);
        expect(find.byType(UsernameScreen), findsOneWidget);
      },
    );

    testWidgets(
      'CASE 6: Authenticated session + complete profile + no Circle -> Cold launch -> Circle Entry',
      (WidgetTester tester) async {
        final readyUser = makeProfile(id: 'usr-no-circles');
        authRepo.setSessionForTesting(readyUser);
        expect(store.getUserCircles(readyUser.id), isEmpty);

        final router = createAppRouter(initialLocation: '/');
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingPage), findsNothing);
        expect(find.byType(CircleEntryPage), findsOneWidget);
      },
    );

    testWidgets(
      'CASE 7: Authenticated session + ready Circle -> Cold launch -> Today',
      (WidgetTester tester) async {
        final readyUser = makeProfile(id: 'usr-ready');
        authRepo.setSessionForTesting(readyUser);

        final circle = store.createCircle(
          name: 'Accountability Duo',
          ownerId: readyUser.id,
        );
        store.addCircleMember(circleId: circle.id, userId: 'usr-peer');
        expect(store.getUserCircles(readyUser.id).length, 1);

        final router = createAppRouter(initialLocation: '/');
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingPage), findsNothing);
        expect(find.byType(TodayPage), findsOneWidget);
      },
    );

    testWidgets('CASE 8: Logout -> Kill/restart -> Screen 1', (
      WidgetTester tester,
    ) async {
      // Step A: User is logged in with an active circle
      final user = makeProfile(id: 'usr-logged-in');
      authRepo.setSessionForTesting(user);
      final circle = store.createCircle(
        name: 'Active Circle',
        ownerId: user.id,
      );
      store.addCircleMember(circleId: circle.id, userId: 'usr-peer');

      // Step B: User logs out
      await authRepo.signOut();

      // Step C: Cold launch after logout
      final router = createAppRouter(initialLocation: '/');
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();

      // MUST start at Onboarding Screen 1
      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(find.text('Commit.\nShow up.\nGrow together.'), findsOneWidget);
      expect(find.byType(TodayPage), findsNothing);
    });
  });
}
