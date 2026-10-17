import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gufi/app/router.dart';
import 'package:gufi/core/services/gufi_backend_store.dart';
import 'package:gufi/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:gufi/features/auth/domain/models/user_profile.dart';
import 'package:gufi/features/circles/domain/models/circle_member.dart';
import 'package:gufi/features/circles/presentation/circle_invite_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  final store = GufiBackendStore.instance;
  final authRepo = SupabaseAuthRepository.instance;

  final testCreator = UserProfile(
    id: 'usr-creator-test',
    email: 'creator@gufi.app',
    emailNormalized: 'creator@gufi.app',
    emailVerified: true,
    username: 'creator',
    usernameNormalized: 'creator',
    displayName: 'Alex Rivers',
    onboardingCompleted: true,
    role: 'user',
    createdAt: DateTime.utc(2026, 10, 16),
    updatedAt: DateTime.utc(2026, 10, 16),
  );

  final testTeammate = UserProfile(
    id: 'usr-teammate-test',
    email: 'teammate@gufi.app',
    emailNormalized: 'teammate@gufi.app',
    emailVerified: true,
    username: 'maya',
    usernameNormalized: 'maya',
    displayName: 'Maya Chen',
    onboardingCompleted: true,
    role: 'user',
    createdAt: DateTime.utc(2026, 10, 16),
    updatedAt: DateTime.utc(2026, 10, 16),
  );

  setUp(() {
    store.reset();
    authRepo.setSessionForTesting(testCreator);
    store.saveUser(testCreator);
    store.saveUser(testTeammate);
  });

  Widget buildSubject({required String circleId, GoRouter? router}) {
    if (router != null) {
      return ProviderScope(child: MaterialApp.router(routerConfig: router));
    }
    return ProviderScope(
      child: MaterialApp(home: CircleInvitePage(circleId: circleId)),
    );
  }

  group('CircleInvitePage (Step 2: Bring your people in)', () {
    testWidgets('1. Pure white background canvas and top bar rendering', (
      tester,
    ) async {
      final circle = store.createCircle(
        name: 'Morning Momentum',
        ownerId: testCreator.id,
      );

      await tester.pumpWidget(buildSubject(circleId: circle.id));
      await tester.pumpAndSettle();

      // Background is pure white #FFFFFF
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFFFFFFF));

      // Top bar
      expect(find.byIcon(CupertinoIcons.arrow_left), findsOneWidget);
      expect(find.text('Create a Circle'), findsOneWidget);
    });

    testWidgets('2. Renders Waiting State when 1 active member exists', (
      tester,
    ) async {
      final circle = store.createCircle(
        name: 'Morning Momentum',
        ownerId: testCreator.id,
      );

      await tester.pumpWidget(buildSubject(circleId: circle.id));
      await tester.pumpAndSettle();

      // Headline and subtitle
      expect(find.text('Bring your people in.'), findsOneWidget);
      expect(
        find.text('A Circle becomes real\nwhen someone joins you.'),
        findsOneWidget,
      );

      // Motif: [YOU] ··· [+]
      expect(find.text('YOU'), findsOneWidget);
      expect(find.text('TEAMMATE'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.plus), findsOneWidget);

      // Circle name and member count
      expect(find.text('Morning Momentum'), findsOneWidget);
      expect(find.text('1 member'), findsOneWidget);

      // Grouped invitation tools
      expect(find.text('Share invite'), findsOneWidget);
      expect(find.text('Invite code'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Show QR code'), findsOneWidget);

      // Waiting status notice
      expect(find.text('Waiting for your first person.'), findsOneWidget);
      expect(
        find.text('As soon as someone joins,\nyour Circle is ready.'),
        findsOneWidget,
      );

      // "Make your first promise" must NOT be visible yet
      expect(find.text('Make your first promise'), findsNothing);
    });

    testWidgets('3. Copy invite code updates state to Copied ✓', (
      tester,
    ) async {
      final circle = store.createCircle(
        name: 'Morning Momentum',
        ownerId: testCreator.id,
      );

      await tester.pumpWidget(buildSubject(circleId: circle.id));
      await tester.pumpAndSettle();

      final copyButton = find.text('Copy');
      expect(copyButton, findsOneWidget);

      await tester.tap(copyButton);
      await tester.pump();

      expect(find.text('Copied ✓'), findsOneWidget);
    });

    testWidgets('4. Show QR code opens clean white bottom sheet with QR', (
      tester,
    ) async {
      final circle = store.createCircle(
        name: 'Morning Momentum',
        ownerId: testCreator.id,
      );

      await tester.pumpWidget(buildSubject(circleId: circle.id));
      await tester.pumpAndSettle();

      final showQrRow = find.text('Show QR code');
      await tester.tap(showQrRow);
      await tester.pumpAndSettle();

      // Bottom sheet contents
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('Scan to join this Circle'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Tap Done closes bottom sheet
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets(
      '5. Realtime 2nd member join transforms page into Ready State (no auto-nav)',
      (tester) async {
        final circle = store.createCircle(
          name: 'Morning Momentum',
          ownerId: testCreator.id,
        );

        await tester.pumpWidget(buildSubject(circleId: circle.id));
        await tester.pumpAndSettle();

        // Currently in waiting state
        expect(find.text('Bring your people in.'), findsOneWidget);
        expect(find.text('1 member'), findsOneWidget);
        expect(find.text('Make your first promise'), findsNothing);

        // Simulate 2nd member joining via store
        store.addCircleMember(
          circleId: circle.id,
          userId: testTeammate.id,
          role: CircleMemberRole.member,
        );
        await tester.pumpAndSettle();

        // Smooth local transform to Ready State!
        expect(find.text('You’re ready.'), findsOneWidget);
        expect(
          find.text('Your Circle has its first teammate.'),
          findsOneWidget,
        );
        expect(find.text('2 members'), findsOneWidget);
        expect(find.text('Maya Chen'), findsOneWidget);
        expect(find.text('Alex Rivers'), findsOneWidget);

        // CTA appears
        expect(find.text('Make your first promise'), findsOneWidget);
      },
    );

    testWidgets(
      '6. Explicit tap on "Make your first promise" routes to /today',
      (tester) async {
        final circle = store.createCircle(
          name: 'Morning Momentum',
          ownerId: testCreator.id,
        );

        // Add 2nd member so it starts in Ready State
        store.addCircleMember(
          circleId: circle.id,
          userId: testTeammate.id,
          role: CircleMemberRole.member,
        );

        final router = createAppRouter(
          initialLocation: '/circle-invite/${circle.id}',
        );

        await tester.pumpWidget(
          buildSubject(circleId: circle.id, router: router),
        );
        await tester.pumpAndSettle();

        expect(find.text('Make your first promise'), findsOneWidget);

        await tester.tap(find.text('Make your first promise'));
        await tester.pumpAndSettle();

        // Routed to Today
        expect(router.state.uri.path, '/today');
      },
    );
  });

  group('Session Restore Rules', () {
    testWidgets('1. Profile incomplete routes to /auth', (tester) async {
      authRepo.setSessionForTesting(
        testCreator.copyWith(onboardingCompleted: false),
      );

      final router = createAppRouter(initialLocation: '/circle-entry');
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/auth');
    });

    testWidgets('2. Profile complete with 0 circles routes to /circle-entry', (
      tester,
    ) async {
      final router = createAppRouter(initialLocation: '/circle-entry');
      await tester.pumpWidget(
        ProviderScope(child: MaterialApp.router(routerConfig: router)),
      );
      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/circle-entry');
    });

    testWidgets(
      '3. Profile complete with 1 circle having 1 member routes to /circle-invite/:id',
      (tester) async {
        final circle = store.createCircle(
          name: 'Solo Circle',
          ownerId: testCreator.id,
        );

        final router = createAppRouter(initialLocation: '/circle-entry');
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router)),
        );
        await tester.pumpAndSettle();

        expect(router.state.uri.path, '/circle-invite/${circle.id}');
      },
    );

    testWidgets(
      '4. Profile complete with circle having >= 2 members routes to /today',
      (tester) async {
        final circle = store.createCircle(
          name: 'Active Duo Circle',
          ownerId: testCreator.id,
        );
        store.addCircleMember(circleId: circle.id, userId: testTeammate.id);

        final router = createAppRouter(initialLocation: '/circle-entry');
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router)),
        );
        await tester.pumpAndSettle();

        expect(router.state.uri.path, '/today');
      },
    );

    testWidgets(
      '5. Multi-circle: Circle A (1 member) + Circle B (2 members) routes to /today',
      (tester) async {
        // Circle A with 1 member
        store.createCircle(name: 'Circle A', ownerId: testCreator.id);

        // Circle B with 2 members
        final circleB = store.createCircle(
          name: 'Circle B',
          ownerId: testCreator.id,
        );
        store.addCircleMember(circleId: circleB.id, userId: testTeammate.id);

        final router = createAppRouter(initialLocation: '/circle-entry');
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router)),
        );
        await tester.pumpAndSettle();

        expect(router.state.uri.path, '/today');
      },
    );
  });
}
