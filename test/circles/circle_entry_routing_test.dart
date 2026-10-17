import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gufi/app/router.dart';
import 'package:gufi/core/services/gufi_backend_store.dart';
import 'package:gufi/features/admin/presentation/admin_dashboard_page.dart';
import 'package:gufi/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:gufi/features/auth/domain/models/user_profile.dart';
import 'package:gufi/features/auth/presentation/auth_page.dart';
import 'package:gufi/features/circles/presentation/circle_entry_page.dart';
import 'package:gufi/features/today/presentation/today_page.dart';

void main() {
  final store = GufiBackendStore.instance;
  final authRepo = SupabaseAuthRepository.instance;

  setUp(() {
    store.reset();
    authRepo.setSessionForTesting(null);
  });

  UserProfile createProfile({
    String id = 'usr-test-1',
    String username = 'testuser',
    bool onboardingCompleted = true,
    bool isAdmin = false,
  }) {
    final now = DateTime.utc(2026, 10, 16);
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

  group('Circle Entry & Routing Logic Gates', () {
    testWidgets('1. profile incomplete + zero Circles -> profile setup', (
      tester,
    ) async {
      final incompleteUser = createProfile(
        id: 'usr-inc',
        username: '',
        onboardingCompleted: false,
      );
      authRepo.setSessionForTesting(incompleteUser);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/auth',
              routes: [
                GoRoute(
                  path: '/auth',
                  builder: (context, state) => const AuthPage(),
                ),
                GoRoute(
                  path: '/circle-entry',
                  builder: (context, state) => const CircleEntryPage(),
                ),
                GoRoute(
                  path: '/today',
                  builder: (context, state) =>
                      const Scaffold(body: Text('Today Screen')),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should be on profile setup (username screen), NOT circle-entry or today
      expect(find.byType(UsernameScreen), findsOneWidget);
      expect(find.byType(CircleEntryPage), findsNothing);
      expect(find.text('Today Screen'), findsNothing);
    });

    testWidgets('2. profile complete + zero active Circles -> Circle Entry', (
      tester,
    ) async {
      final user = createProfile(id: 'usr-zero-circles');
      authRepo.setSessionForTesting(user);

      // Verify user has 0 circles in store
      expect(store.getUserCircles(user.id), isEmpty);

      final router = createAppRouter(
        initialLocation: '/today',
        navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'test-2'),
      );

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();

      // Guard should redirect zero-circle user to /circle-entry
      expect(find.byType(CircleEntryPage), findsOneWidget);
      expect(find.textContaining('Everything feels'), findsOneWidget);
      expect(find.byType(TodayPage), findsNothing);
    });

    testWidgets(
      '3. profile complete + one active Circle with >= 2 members -> Today',
      (tester) async {
        final user = createProfile(id: 'usr-one-circle');
        authRepo.setSessionForTesting(user);

        // Create 1 active circle for user with 2 members
        final c1 = store.createCircle(
          name: 'Morning Routine',
          ownerId: user.id,
        );
        store.addCircleMember(circleId: c1.id, userId: 'usr-teammate-1');
        expect(store.getUserCircles(user.id).length, 1);

        final router = createAppRouter(
          initialLocation: '/today',
          navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'test-3'),
        );

        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router)),
        );
        await tester.pumpAndSettle();

        // Allowed to land on Today
        expect(find.byType(CircleEntryPage), findsNothing);
        expect(find.byType(TodayPage), findsOneWidget);
      },
    );

    testWidgets('4. profile complete + multiple active Circles -> Today', (
      tester,
    ) async {
      final user = createProfile(id: 'usr-multi-circles');
      authRepo.setSessionForTesting(user);

      // Create 2 active circles
      store.createCircle(name: 'DSA Grind', ownerId: user.id);
      final c2 = store.createCircle(name: 'Fitness 75', ownerId: 'other-user');
      store.addCircleMember(circleId: c2.id, userId: user.id);
      expect(store.getUserCircles(user.id).length, 2);

      final router = createAppRouter(
        initialLocation: '/today',
        navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'test-4'),
      );

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircleEntryPage), findsNothing);
      expect(find.byType(TodayPage), findsOneWidget);
    });

    testWidgets('5. inactive/removed membership only -> Circle Entry', (
      tester,
    ) async {
      final user = createProfile(id: 'usr-removed-circle');
      authRepo.setSessionForTesting(user);

      // Create a circle and remove user
      final c1 = store.createCircle(name: 'Old Circle', ownerId: 'other-user');
      store.addCircleMember(circleId: c1.id, userId: user.id);
      // Remove user membership
      store.removeCircleMember(circleId: c1.id, userId: user.id);

      // Verify active membership count is 0
      expect(store.getUserCircles(user.id), isEmpty);

      final router = createAppRouter(
        initialLocation: '/today',
        navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'test-5'),
      );

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();

      // Must be redirected to Circle Entry
      expect(find.byType(CircleEntryPage), findsOneWidget);
      expect(find.text('Create a Circle'), findsOneWidget);
      expect(find.byType(TodayPage), findsNothing);
    });

    testWidgets('6. admin -> Admin', (tester) async {
      final adminUser = createProfile(id: 'usr-admin', isAdmin: true);
      authRepo.setSessionForTesting(adminUser);

      final router = createAppRouter(
        initialLocation: '/admin',
        navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'test-6'),
      );

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();

      // Admin page should load
      expect(find.byType(AdminDashboardPage), findsOneWidget);
      expect(find.byType(CircleEntryPage), findsNothing);
    });

    testWidgets(
      '7. restored session with ready Circle (>= 2 members) -> Today',
      (tester) async {
        final user = createProfile(id: 'usr-restored-with-circle');
        authRepo.setSessionForTesting(user);
        final c = store.createCircle(
          name: 'Accountability Squad',
          ownerId: user.id,
        );
        store.addCircleMember(circleId: c.id, userId: 'usr-squad-member');

        final router = createAppRouter(
          initialLocation: '/circle-entry',
          navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'test-7'),
        );

        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router)),
        );
        await tester.pumpAndSettle();

        // User with ready circle attempting /circle-entry should redirect to /today
        expect(find.byType(CircleEntryPage), findsNothing);
        expect(find.byType(TodayPage), findsOneWidget);
      },
    );

    testWidgets('8. restored session with zero Circles -> Circle Entry', (
      tester,
    ) async {
      final user = createProfile(id: 'usr-restored-zero-circles');
      authRepo.setSessionForTesting(user);
      expect(store.getUserCircles(user.id), isEmpty);

      final router = createAppRouter(
        initialLocation: '/today',
        navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'test-8'),
      );

      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircleEntryPage), findsOneWidget);
      expect(find.text('Join a Circle'), findsOneWidget);
      expect(find.byType(TodayPage), findsNothing);
    });
  });

  group('Circle Entry Screen UI and Content Validation', () {
    testWidgets(
      'Circle Entry contains required copy, identity, and no bypass/skip',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: CircleEntryPage())),
        );
        await tester.pumpAndSettle();

        // Brand Wordmark
        expect(find.text('Gufi'), findsOneWidget);

        // Top-right handwritten note removed to keep top section calm and editorial
        expect(find.text('Better together.'), findsNothing);

        // Main Two-Tone Heading in Gambarino
        expect(find.textContaining('Everything feels'), findsOneWidget);
        expect(find.textContaining('easier with'), findsOneWidget);

        // Handwritten Annotations around characters
        expect(find.text('Stay\naccountable'), findsOneWidget);
        expect(find.text('Support\neach other'), findsOneWidget);
        expect(find.text('Grow together'), findsOneWidget);

        // Primary Option
        expect(find.text('Create a Circle'), findsOneWidget);
        expect(find.text('Start something with your people.'), findsOneWidget);

        // Secondary Option
        expect(find.text('Join a Circle'), findsOneWidget);
        expect(find.text('Already invited? Come in.'), findsOneWidget);

        // Reassuring Privacy Card
        expect(
          find.text(
            'Circles are private spaces for you\nand people you trust.',
          ),
          findsOneWidget,
        );

        // Strict Negative Assertions:
        // No Skip
        expect(find.text('Skip'), findsNothing);
        expect(find.text('Maybe later'), findsNothing);
        expect(find.text('Continue alone'), findsNothing);

        // No Private / Solo mode
        expect(find.text('Personal (Solo)'), findsNothing);
        expect(find.text('Solo'), findsNothing);

        // No fake circle data
        expect(find.text('DSA Grind'), findsNothing);
        expect(find.text('Fitness 75'), findsNothing);

        // Strict No-Scroll Architecture: Absolutely no scroll views or vertical scroll physics
        expect(find.byType(SingleChildScrollView), findsNothing);
        expect(find.byType(ListView), findsNothing);
        expect(find.byType(CustomScrollView), findsNothing);
        expect(find.byType(Scrollable), findsNothing);

        // Action Card Consistency: Exactly two action cards with identical sizes
        final createCardFinder = find.ancestor(
          of: find.text('Create a Circle'),
          matching: find.byType(Ink),
        );
        final joinCardFinder = find.ancestor(
          of: find.text('Join a Circle'),
          matching: find.byType(Ink),
        );
        expect(createCardFinder, findsOneWidget);
        expect(joinCardFinder, findsOneWidget);

        final createCardSize = tester.getSize(createCardFinder);
        final joinCardSize = tester.getSize(joinCardFinder);

        expect(createCardSize.height, equals(joinCardSize.height));
        expect(createCardSize.width, equals(joinCardSize.width));
        expect(createCardSize.height, equals(98.0));
      },
    );
  });
}
