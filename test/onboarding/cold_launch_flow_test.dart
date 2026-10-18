import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/app/router.dart';
import 'package:gufi/core/services/app_preferences_service.dart';
import 'package:gufi/core/services/gufi_backend_store.dart';
import 'package:gufi/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:gufi/features/auth/domain/models/user_profile.dart';
import 'package:gufi/features/auth/presentation/auth_page.dart';
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
      role: 'user',
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('TEST 1: Unauthenticated cold launch -> Onboarding Screen 1', (
    tester,
  ) async {
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
  });

  testWidgets('TEST 2: Screen 1 -> Screen 2 -> works', (tester) async {
    authRepo.setSessionForTesting(null);
    final router = createAppRouter(initialLocation: '/');

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    // Tap arrow on Screen 1
    await tester.tap(find.byType(CircularArrowButton));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen2), findsOneWidget);
    expect(find.text('Small steps.\nReal momentum.'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('TEST 3: Screen 2 -> Welcome -> works', (tester) async {
    authRepo.setSessionForTesting(null);
    final router = createAppRouter(initialLocation: '/');

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    // Screen 1 -> Screen 2
    await tester.tap(find.byType(CircularArrowButton));
    await tester.pumpAndSettle();

    // Screen 2 -> Welcome
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.text('Welcome to Gufi'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });

  testWidgets('TEST 4: Welcome -> Login -> works', (tester) async {
    authRepo.setSessionForTesting(null);
    final router = createAppRouter(initialLocation: '/');

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CircularArrowButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Welcome -> Login
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('TEST 5: Login -> Welcome -> works', (tester) async {
    authRepo.setSessionForTesting(null);
    final router = createAppRouter(initialLocation: '/');

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CircularArrowButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back.'), findsOneWidget);

    // Tap back button
    final backButton = find.bySemanticsLabel('Back').last;
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Gufi'), findsOneWidget);
    expect(find.text('Welcome back.'), findsNothing);
  });

  testWidgets(
    'TEST 6: Transition implementation cannot change initial screen',
    (tester) async {
      authRepo.setSessionForTesting(null);

      // Even if user previously navigated through auth, a new unauthenticated app instance starts at Screen 1
      final router = createAppRouter(initialLocation: '/');
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingPage), findsOneWidget);
      expect(find.byType(AuthPage), findsNothing);
    },
  );

  testWidgets(
    'TEST 7: Authenticated launch -> existing authenticated bootstrap still works',
    (tester) async {
      final user = makeProfile(id: 'usr-ready');
      authRepo.setSessionForTesting(user);

      final circle = store.createCircle(name: 'The Circle', ownerId: user.id);
      store.addCircleMember(circleId: circle.id, userId: 'usr-peer');
      expect(store.getUserCircles(user.id).length, 1);

      final router = createAppRouter(initialLocation: '/');
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();

      // Authenticated bootstrap routes directly to Today
      expect(find.byType(OnboardingPage), findsNothing);
      expect(find.byType(AuthPage), findsNothing);
      expect(find.byType(TodayPage), findsOneWidget);
    },
  );
}
