import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/core/services/gufi_backend_store.dart';
import 'package:gufi/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:gufi/features/auth/domain/models/user_profile.dart';
import 'package:gufi/features/circles/presentation/circle_create_page.dart';

void main() {
  final store = GufiBackendStore.instance;
  final authRepo = SupabaseAuthRepository.instance;

  setUp(() {
    store.reset();
    authRepo.setSessionForTesting(
      UserProfile(
        id: 'usr-creator-test',
        email: 'creator@gufi.app',
        emailNormalized: 'creator@gufi.app',
        emailVerified: true,
        username: 'creator',
        usernameNormalized: 'creator',
        displayName: 'Creator Test',
        onboardingCompleted: true,
        role: 'user',
        createdAt: DateTime.utc(2026, 10, 16),
        updatedAt: DateTime.utc(2026, 10, 16),
      ),
    );
  });

  Widget buildSubject({VoidCallback? onCreated}) {
    return MaterialApp(home: CircleCreatePage(onCreated: onCreated));
  }

  group('CircleCreatePage (Step 1) UI & Form Validation', () {
    testWidgets('1. Renders top bar, headline, and supporting copy', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Top bar
      expect(find.byIcon(CupertinoIcons.arrow_left), findsOneWidget);
      expect(find.text('Create a Circle'), findsOneWidget);

      // Headline and subtitle
      expect(find.text('Name your Circle.'), findsOneWidget);
      expect(find.text('Start your Circle.'), findsNothing);
      expect(
        find.text('Give your group a name and a reason to show up together.'),
        findsOneWidget,
      );

      // Verify no-scroll physics when keyboard is closed
      final scrollableFinder = find.byType(SingleChildScrollView);
      expect(scrollableFinder, findsOneWidget);
      final scrollView = tester.widget<SingleChildScrollView>(scrollableFinder);
      expect(scrollView.physics, isA<NeverScrollableScrollPhysics>());

      // Field labels
      expect(find.text('Circle name'), findsOneWidget);
      expect(find.text('What’s this Circle for?'), findsOneWidget);

      // Placeholders
      expect(find.text('e.g. Morning Momentum'), findsOneWidget);
      expect(
        find.text(
          'Show up daily, stay accountable, and finish what we say we’ll do.',
        ),
        findsOneWidget,
      );

      // Privacy info card
      expect(find.text('Private by default'), findsOneWidget);
      expect(
        find.text(
          'Only invited members can join and only your Circle can see what you share.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(CupertinoIcons.lock_fill), findsOneWidget);

      // CTA
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('2. CTA is disabled by default on empty form', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Find the submit button ink container
      final submitFinder = find.widgetWithText(InkWell, 'Continue');
      expect(submitFinder, findsOneWidget);

      final inkWell = tester.widget<InkWell>(submitFinder);
      expect(inkWell.onTap, isNull); // Disabled
    });

    testWidgets('3. Enforces 3 to 24 character constraint on Circle Name', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final nameField = find.widgetWithText(TextField, 'e.g. Morning Momentum');
      expect(nameField, findsOneWidget);

      // 1 char -> disabled
      await tester.enterText(nameField, 'A');
      await tester.pump();
      expect(
        tester.widget<InkWell>(find.widgetWithText(InkWell, 'Continue')).onTap,
        isNull,
      );

      // 2 chars -> disabled
      await tester.enterText(nameField, 'AB');
      await tester.pump();
      expect(
        tester.widget<InkWell>(find.widgetWithText(InkWell, 'Continue')).onTap,
        isNull,
      );

      // 3 chars -> enabled
      await tester.enterText(nameField, 'ABC');
      await tester.pump();
      expect(
        tester.widget<InkWell>(find.widgetWithText(InkWell, 'Continue')).onTap,
        isNotNull,
      );

      // 24 chars -> enabled
      await tester.enterText(nameField, '123456789012345678901234');
      await tester.pump();
      expect(
        tester.widget<InkWell>(find.widgetWithText(InkWell, 'Continue')).onTap,
        isNotNull,
      );

      // 25 chars -> truncated to 24 due to maxLength enforcement
      await tester.enterText(nameField, '1234567890123456789012345');
      await tester.pump();
      expect(find.text('123456789012345678901234'), findsOneWidget);
    });

    testWidgets('4. Shows live character count for purpose up to 80 chars', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('0/80'), findsOneWidget);

      final purposeField = find.byType(TextField).last;
      await tester.enterText(purposeField, 'Stay accountable every morning.');
      await tester.pump();

      expect(find.text('31/80'), findsOneWidget);
    });

    testWidgets(
      '5. Successful creation creates circle in store and triggers onCreated',
      (tester) async {
        bool callbackTriggered = false;

        await tester.pumpWidget(
          buildSubject(
            onCreated: () {
              callbackTriggered = true;
            },
          ),
        );
        await tester.pumpAndSettle();

        final nameField = find.widgetWithText(
          TextField,
          'e.g. Morning Momentum',
        );
        await tester.enterText(nameField, 'Morning Momentum');
        await tester.pump();

        final continueButton = find.widgetWithText(InkWell, 'Continue');
        await tester.tap(continueButton);
        await tester.pumpAndSettle();

        expect(callbackTriggered, isTrue);

        // Verify circle is in store
        final userCircles = store.getUserCircles('usr-creator-test');
        expect(userCircles.length, 1);
        expect(userCircles.first.name, 'Morning Momentum');
      },
    );
  });
}
