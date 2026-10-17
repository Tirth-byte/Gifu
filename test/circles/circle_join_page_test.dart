import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gufi/core/services/gufi_backend_store.dart';
import 'package:gufi/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:gufi/features/auth/domain/models/user_profile.dart';
import 'package:gufi/features/circles/data/repositories/supabase_circle_repository.dart';
import 'package:gufi/features/circles/domain/models/circle_invite.dart';
import 'package:gufi/features/circles/presentation/circle_join_page.dart';

void main() {
  setUp(() {
    GufiBackendStore.instance.reset();
    SupabaseAuthRepository.instance.setSessionForTesting(null);
  });

  UserProfile createUser({
    required String id,
    required String username,
    String? displayName,
  }) {
    final now = DateTime.now();
    return UserProfile(
      id: id,
      email: '$username@example.com',
      emailNormalized: '$username@example.com',
      emailVerified: true,
      username: username,
      usernameNormalized: username,
      displayName: displayName ?? username,
      createdAt: now,
      updatedAt: now,
    );
  }

  Widget buildTestWidget({
    String? initialCode,
    UserProfile? currentUser,
    GoRouter? router,
  }) {
    SupabaseAuthRepository.instance.setSessionForTesting(currentUser);

    if (router != null) {
      return MaterialApp.router(routerConfig: router);
    }

    return MaterialApp(
      home: Scaffold(body: CircleJoinPage(initialCode: initialCode)),
    );
  }

  group('CircleJoinPage Unit & Flow Tests', () {
    testWidgets(
      '1. Renders headline, input, Find button, QR row, and trust text',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Join a Circle'), findsOneWidget);
        expect(find.text('Find your Circle.'), findsOneWidget);
        expect(
          find.text('Enter the invite code someone shared with you.'),
          findsOneWidget,
        );
        expect(find.text('Invite code'), findsOneWidget);
        expect(find.text('Find Circle'), findsOneWidget);
        expect(find.text('Scan QR code'), findsOneWidget);
        expect(
          find.text('You’ll preview the Circle before joining.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '2. Valid invite code: resolves preview WITHOUT creating membership (NO AUTO JOIN)',
      (tester) async {
        final store = GufiBackendStore.instance;
        final creator = createUser(
          id: 'usr-creator-1',
          username: 'creator_manish',
          displayName: 'Manish',
        );
        store.saveUser(creator);

        final circle = store.createCircle(
          name: 'Morning Momentum',
          ownerId: creator.id,
          description: 'Show up daily and keep each other accountable.',
          inviteCode: 'GUFI-7K4PX9',
        );

        final joiner = createUser(
          id: 'usr-joiner-1',
          username: 'joiner_alex',
          displayName: 'Alex',
        );
        store.saveUser(joiner);

        await tester.pumpWidget(buildTestWidget(currentUser: joiner));
        await tester.pumpAndSettle();

        // Enter code
        await tester.enterText(find.byType(TextField), 'GUFI-7K4PX9');
        await tester.pumpAndSettle();

        // Tap Find Circle
        await tester.tap(find.text('Find Circle'));
        await tester.pumpAndSettle();

        // Preview Headline & Subtitle
        expect(find.text('This is your Circle.'), findsOneWidget);
        expect(find.text('Take a look before you join.'), findsOneWidget);

        // Preview Card content
        expect(find.text('Morning Momentum'), findsOneWidget);
        expect(
          find.text('Show up daily and keep each other accountable.'),
          findsOneWidget,
        );
        expect(find.text('1 person'), findsOneWidget);
        expect(find.text('Invited by Manish'), findsOneWidget);
        expect(find.text('Join Circle'), findsOneWidget);
        expect(find.text('Use another code'), findsOneWidget);

        // CRITICAL: Membership MUST NOT be created yet!
        expect(
          store.isUserCircleMember(circleId: circle.id, userId: joiner.id),
          isFalse,
        );
        expect(store.getCircleMembers(circle.id).length, 1);
      },
    );

    testWidgets(
      '3. Confirm Join: tap Join Circle creates active membership and routes to /today',
      (tester) async {
        final store = GufiBackendStore.instance;
        final creator = createUser(
          id: 'usr-creator-2',
          username: 'creator_dhyati',
          displayName: 'Dhyati',
        );
        store.saveUser(creator);

        final circle = store.createCircle(
          name: 'DSA Grind',
          ownerId: creator.id,
          inviteCode: 'GUFI-DSA234',
        );

        final joiner = createUser(
          id: 'usr-joiner-2',
          username: 'joiner_bob',
          displayName: 'Bob',
        );
        store.saveUser(joiner);

        bool navigatedToToday = false;
        final router = GoRouter(
          initialLocation: '/circle-join',
          routes: [
            GoRoute(
              path: '/circle-join',
              builder: (context, state) =>
                  const CircleJoinPage(initialCode: 'GUFI-DSA234'),
            ),
            GoRoute(
              path: '/today',
              builder: (context, state) {
                navigatedToToday = true;
                return const Scaffold(body: Text('Today Screen'));
              },
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestWidget(currentUser: joiner, router: router),
        );
        await tester.pumpAndSettle();

        // Preview is automatically resolved via initialCode
        expect(find.text('DSA Grind'), findsOneWidget);
        expect(find.text('Join Circle'), findsOneWidget);

        // Tap Join Circle
        await tester.tap(find.text('Join Circle'));
        await tester.pumpAndSettle();

        // Membership should now be created!
        expect(
          store.isUserCircleMember(circleId: circle.id, userId: joiner.id),
          isTrue,
        );
        expect(store.getCircleMembers(circle.id).length, 2);

        // Navigated to /today
        expect(navigatedToToday, isTrue);
        expect(find.text('Today Screen'), findsOneWidget);
      },
    );

    testWidgets('4. Invalid code shows inline error and keeps entered text', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'GUFI-INVALID');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Find Circle'));
      await tester.pumpAndSettle();

      // Error shown inline
      expect(find.text('We couldn’t find that invite.'), findsOneWidget);

      // Entered code remains in TextField so user can edit
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'GUFI-INVALID');
    });

    testWidgets('5. Expired invite shows correct expired notice', (
      tester,
    ) async {
      final store = GufiBackendStore.instance;
      final creator = createUser(
        id: 'usr-creator-3',
        username: 'creator_exp',
        displayName: 'Exp Creator',
      );
      store.saveUser(creator);

      final circle = store.createCircle(
        name: 'Timed Circle',
        ownerId: creator.id,
      );

      // Create an already-expired invite
      store.createCircleInvite(
        circleId: circle.id,
        creatorId: creator.id,
        customCode: 'GUFI-EXPD99',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'GUFI-EXPD99');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Find Circle'));
      await tester.pumpAndSettle();

      expect(find.text('This invite has expired.'), findsOneWidget);
      expect(
        find.text('Ask someone in the Circle for a new invite.'),
        findsOneWidget,
      );
      expect(find.text('Use another code'), findsOneWidget);
    });

    testWidgets('6. Revoked invite shows correct inactive notice', (
      tester,
    ) async {
      final store = GufiBackendStore.instance;
      final creator = createUser(
        id: 'usr-creator-4',
        username: 'creator_rev',
        displayName: 'Rev Creator',
      );
      store.saveUser(creator);

      store.createCircle(
        name: 'Closed Circle',
        ownerId: creator.id,
        inviteCode: 'GUFI-REV234',
      );

      store.updateInviteStatus('GUFI-REV234', CircleInviteStatus.revoked);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'GUFI-REV234');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Find Circle'));
      await tester.pumpAndSettle();

      expect(find.text('This invite is no longer active.'), findsOneWidget);
      expect(find.text('Use another code'), findsOneWidget);
    });

    testWidgets(
      '7. Already a member displays info state without error or duplicate',
      (tester) async {
        final store = GufiBackendStore.instance;
        final user = createUser(
          id: 'usr-member-1',
          username: 'member_user',
          displayName: 'Member User',
        );
        store.saveUser(user);

        // User creates (and is therefore already a member of) this circle
        store.createCircle(
          name: 'My Own Circle',
          ownerId: user.id,
          inviteCode: 'GUFI-MINE23',
        );

        bool navigatedToToday = false;
        final router = GoRouter(
          initialLocation: '/circle-join',
          routes: [
            GoRoute(
              path: '/circle-join',
              builder: (context, state) =>
                  const CircleJoinPage(initialCode: 'GUFI-MINE23'),
            ),
            GoRoute(
              path: '/today',
              builder: (context, state) {
                navigatedToToday = true;
                return const Scaffold(body: Text('Today Screen'));
              },
            ),
          ],
        );

        await tester.pumpWidget(
          buildTestWidget(currentUser: user, router: router),
        );
        await tester.pumpAndSettle();

        // Headline shows "You’re already in this Circle."
        expect(find.text('You’re already in this Circle.'), findsOneWidget);
        expect(find.text('Go to Today'), findsOneWidget);
        expect(find.text('Use another code'), findsOneWidget);

        await tester.tap(find.text('Go to Today'));
        await tester.pumpAndSettle();

        expect(navigatedToToday, isTrue);
      },
    );

    testWidgets('8. Use another code returns to clean entry state', (
      tester,
    ) async {
      final store = GufiBackendStore.instance;
      final creator = createUser(
        id: 'usr-creator-swap',
        username: 'creator_swap',
        displayName: 'Swap Creator',
      );
      store.saveUser(creator);

      store.createCircle(
        name: 'Swap Circle',
        ownerId: creator.id,
        inviteCode: 'GUFI-SWAP23',
      );

      final joiner = createUser(id: 'usr-joiner-swap', username: 'joiner_swap');
      store.saveUser(joiner);

      await tester.pumpWidget(
        buildTestWidget(currentUser: joiner, initialCode: 'GUFI-SWAP23'),
      );
      await tester.pumpAndSettle();

      // In preview
      expect(find.text('This is your Circle.'), findsOneWidget);
      expect(find.text('Swap Circle'), findsOneWidget);

      // Tap Use another code
      await tester.tap(find.text('Use another code'));
      await tester.pumpAndSettle();

      // Returns to entry state
      expect(find.text('Find your Circle.'), findsOneWidget);
      expect(
        find.text('Enter the invite code someone shared with you.'),
        findsOneWidget,
      );
      expect(find.text('Find Circle'), findsOneWidget);
      expect(find.text('Scan QR code'), findsOneWidget);
      expect(find.text('Swap Circle'), findsNothing);
    });

    testWidgets('9. Lowercase and spaces are normalized automatically', (
      tester,
    ) async {
      final store = GufiBackendStore.instance;
      final creator = createUser(
        id: 'usr-creator-5',
        username: 'creator_norm',
        displayName: 'Norm Creator',
      );
      store.saveUser(creator);

      store.createCircle(
        name: 'Normalized Group',
        ownerId: creator.id,
        inviteCode: 'GUFI-NORM23',
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Type lowercase with extra spaces
      await tester.enterText(find.byType(TextField), '  gufi-norm23  ');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Find Circle'));
      await tester.pumpAndSettle();

      expect(find.text('Normalized Group'), findsOneWidget);
    });

    testWidgets('10. Deep link URL with code is parsed and resolved', (
      tester,
    ) async {
      final store = GufiBackendStore.instance;
      final creator = createUser(
        id: 'usr-creator-6',
        username: 'creator_deep',
        displayName: 'Deep Creator',
      );
      store.saveUser(creator);

      store.createCircle(
        name: 'Deep Link Squad',
        ownerId: creator.id,
        inviteCode: 'GUFI-DEEP23',
      );

      // Deep link URL format
      await tester.pumpWidget(
        buildTestWidget(initialCode: 'https://gufi.app/join/GUFI-DEEP23'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Deep Link Squad'), findsOneWidget);
      expect(find.text('Join Circle'), findsOneWidget);
    });

    testWidgets('11. Double tap Join Circle prevents duplicate memberships', (
      tester,
    ) async {
      final store = GufiBackendStore.instance;
      final creator = createUser(
        id: 'usr-creator-dbl',
        username: 'creator_dbl',
        displayName: 'Dbl Creator',
      );
      store.saveUser(creator);

      final circle = store.createCircle(
        name: 'Double Tap Squad',
        ownerId: creator.id,
        inviteCode: 'GUFI-DBL234',
      );

      final joiner = createUser(id: 'usr-joiner-dbl', username: 'joiner_dbl');
      store.saveUser(joiner);

      final router = GoRouter(
        initialLocation: '/circle-join',
        routes: [
          GoRoute(
            path: '/circle-join',
            builder: (context, state) =>
                const CircleJoinPage(initialCode: 'GUFI-DBL234'),
          ),
          GoRoute(
            path: '/today',
            builder: (context, state) =>
                const Scaffold(body: Text('Today Screen')),
          ),
        ],
      );

      await tester.pumpWidget(
        buildTestWidget(currentUser: joiner, router: router),
      );
      await tester.pumpAndSettle();

      // Double tap Join Circle
      await tester.tap(find.text('Join Circle'));
      await tester.tap(find.text('Join Circle'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Only 1 membership for joiner created
      final members = store.getCircleMembers(circle.id);
      expect(members.where((m) => m.userId == joiner.id).length, 1);
      expect(members.length, 2);
    });

    testWidgets('12. Unauthorized backend join request is safely rejected', (
      tester,
    ) async {
      final repo = SupabaseCircleRepository.instance;
      final result = await repo.joinCircleWithInvite(
        code: 'GUFI-FAKE23',
        userId: 'usr-nonexistent',
      );

      expect(result, isA<JoinCircleFailure>());
      expect((result as JoinCircleFailure).message, isNotEmpty);
    });
  });
}
