import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/app/app.dart';
import 'package:gufi/app/router.dart';
import 'package:gufi/features/auth/presentation/auth_page.dart';
import 'package:gufi/features/onboarding/presentation/components/circular_arrow_button.dart';
import 'package:gufi/features/onboarding/presentation/onboarding_page.dart';
import 'package:gufi/core/services/gufi_backend_store.dart';
import 'package:gufi/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:hugeicons/hugeicons.dart';

void main() {
  setUp(() {
    GufiBackendStore.instance.reset();
    SupabaseAuthRepository.instance.signOut();
  });
  testWidgets('OnboardingPage renders headline, indicator, and next button', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(find.text('Commit.\nShow up.\nGrow together.'), findsOneWidget);
    expect(find.text('Make it visible. Follow through.'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
  });

  testWidgets('OnboardingPage layout resilience on compact screens', (
    WidgetTester tester,
  ) async {
    // iPhone SE dimensions (375x667)
    tester.view.physicalSize = const Size(375 * 2, 667 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Commit.\nShow up.\nGrow together.'), findsOneWidget);
  });

  testWidgets(
    'Navigation from Screen 1 to Screen 2 renders headline, back and continue buttons',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const ProviderScope(child: App()));
      await tester.pumpAndSettle();

      // Tap CTA arrow button on Screen 1
      final ctaButton = find.byType(CircularArrowButton);
      expect(ctaButton, findsOneWidget);
      await tester.tap(ctaButton);
      await tester.pump(const Duration(milliseconds: 200)); // Tap delay
      await tester.pump(const Duration(milliseconds: 500)); // Transition

      // Verify Screen 2 content
      expect(find.text('Small steps.\nReal momentum.'), findsOneWidget);
      expect(
        find.text('Turn daily intentions into\nconsistent follow-through.'),
        findsOneWidget,
      );
      expect(find.text('Continue'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Verify returned to Screen 1
      expect(find.text('Commit.\nShow up.\nGrow together.'), findsOneWidget);
    },
  );

  testWidgets('Screen 2 renders Gufi Momentum Meter with 87% and labels', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();

    // Navigate to Screen 2
    final ctaButton = find.byType(CircularArrowButton);
    await tester.tap(ctaButton);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify initial entrance
    expect(find.text('Small steps.\nReal momentum.'), findsOneWidget);
    expect(find.text('Momentum'), findsOneWidget);
    expect(find.text('Show up'), findsOneWidget);
    expect(find.text('Repeat'), findsOneWidget);
    expect(find.text('Grow'), findsOneWidget);

    // Pump through momentum animation (1850ms)
    await tester.pump(const Duration(milliseconds: 2000));

    // Value should reach 87%
    expect(find.text('87%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Auth completes the full email signup path', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: AuthPage()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Gufi'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);

    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    expect(find.text("What's your email?"), findsOneWidget);
    expect(
      find.text("We'll use this to create your Gufi account."),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'new@gufi.app');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Create a password'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'securepass');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Confirm your\npassword'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'securepass');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('What should we\ncall you?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'tirth');
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('✓ Username available'), findsOneWidget);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Make it yours.'), findsOneWidget);
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(find.text('Authentication flow complete.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Auth supports login and password reset while preserving email', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: AuthPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'hello@gufi.app');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Enter your\npassword'), findsOneWidget);
    expect(find.text('hello@gufi.app'), findsOneWidget);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your\npassword'), findsOneWidget);
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Check your email.'), findsOneWidget);
    expect(find.text('Back to log in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Onboarding Continue opens the auth welcome screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    appRouter.go('/screen-2');
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();
    expect(find.text('Small steps.\nReal momentum.'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(AuthPage), findsOneWidget);
    expect(find.text('Welcome to Gufi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Auth welcome screen renders without overflow on compact heights',
    (WidgetTester tester) async {
      // 354 x 464 constraint simulation
      tester.view.physicalSize = const Size(354 * 2, 464 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MaterialApp(home: AuthPage()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to Gufi'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);
      expect(find.text('Log in'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Welcome screen renders standard Gufi Auth back button with specs',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MaterialApp(home: AuthPage()));
      await tester.pumpAndSettle();

      // Verify BackControl is present
      final backFinder = find.byType(BackControl);
      expect(backFinder, findsOneWidget);

      final backWidget = tester.widget<BackControl>(backFinder);
      expect(backWidget.size, 50.0);

      // Verify HugeIcon chevron with navy color
      final iconFinder = find.descendant(
        of: backFinder,
        matching: find.byType(HugeIcon),
      );
      expect(iconFinder, findsOneWidget);
      final iconWidget = tester.widget<HugeIcon>(iconFinder);
      expect(iconWidget.icon, HugeIcons.strokeRoundedArrowLeft01);
      expect(iconWidget.color, const Color(0xFF1E3365));

      // Verify micro-interaction (scale decreases on press down)
      final animatedScaleFinder = find.descendant(
        of: backFinder,
        matching: find.byType(AnimatedScale),
      );
      expect(animatedScaleFinder, findsOneWidget);
      final scaleBefore = tester
          .widget<AnimatedScale>(animatedScaleFinder)
          .scale;
      expect(scaleBefore, 1.0);

      final gesture = await tester.startGesture(tester.getCenter(backFinder));
      await tester.pump(const Duration(milliseconds: 50));
      final scalePressed = tester
          .widget<AnimatedScale>(animatedScaleFinder)
          .scale;
      expect(scalePressed, 0.92);

      await gesture.up();
      await tester.pumpAndSettle();
      final scaleAfter = tester
          .widget<AnimatedScale>(animatedScaleFinder)
          .scale;
      expect(scaleAfter, 1.0);
    },
  );

  testWidgets(
    'Tapping Welcome screen back button returns to Onboarding Screen 2 and preserves state',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      appRouter.go('/screen-2');
      await tester.pumpWidget(const ProviderScope(child: App()));
      await tester.pumpAndSettle();

      // Verify on Screen 2
      expect(find.text('Small steps.\nReal momentum.'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // Navigate to Auth Welcome Screen
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(AuthPage), findsOneWidget);
      expect(find.text('Welcome to Gufi'), findsOneWidget);

      // Tap the Auth Back Button
      final backFinder = find.byType(BackControl);
      expect(backFinder, findsOneWidget);
      await tester.tap(backFinder);
      await tester.pumpAndSettle();

      // Verify returned to Screen 2 and state is preserved
      expect(find.text('Small steps.\nReal momentum.'), findsOneWidget);
      expect(
        find.text('Turn daily intentions into\nconsistent follow-through.'),
        findsOneWidget,
      );
      expect(find.byType(AuthPage), findsNothing);
    },
  );

  testWidgets(
    'System back navigation on Welcome screen returns to Onboarding Screen 2 and does not exit app',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      appRouter.go('/screen-2');
      await tester.pumpWidget(const ProviderScope(child: App()));
      await tester.pumpAndSettle();

      // Navigate to Auth Welcome Screen
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(AuthPage), findsOneWidget);
      expect(find.text('Welcome to Gufi'), findsOneWidget);

      // Simulate system back (Android system back / iOS back navigation)
      final didPop = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(didPop, isTrue);

      // Verify returned to Screen 2 and did not exit app
      expect(find.text('Small steps.\nReal momentum.'), findsOneWidget);
      expect(find.byType(AuthPage), findsNothing);
    },
  );

  testWidgets(
    'Welcome screen hero composition adheres to typography and layout hierarchy',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MaterialApp(home: AuthPage()));
      // Pump initial frame to test entrance
      await tester.pump();
      expect(find.text('Welcome to Gufi'), findsOneWidget);

      await tester.pumpAndSettle();

      // Check symbol
      final symbolFinder = find.byType(Image);
      expect(symbolFinder, findsOneWidget);
      final Image symbolWidget = tester.widget(symbolFinder);
      expect(symbolWidget.width, 124.0);
      expect(symbolWidget.height, 124.0);

      // Check headline
      final headlineFinder = find.text('Welcome to Gufi');
      expect(headlineFinder, findsOneWidget);
      final Text headlineWidget = tester.widget(headlineFinder);
      expect(headlineWidget.maxLines, 1);
      expect(headlineWidget.style?.fontSize, 48.0);

      // Check subtitle
      final subtitleFinder = find.text('Show up. Follow through. Together.');
      expect(subtitleFinder, findsOneWidget);
      final Text subtitleWidget = tester.widget(subtitleFinder);
      expect(subtitleWidget.style?.fontSize, 16.5);
      expect(subtitleWidget.style?.color, const Color(0xFF5A6A85));

      // Check vertical layout hierarchy: symbol above headline, headline above subtitle, actions below
      final symbolBottom = tester.getBottomLeft(symbolFinder).dy;
      final headlineTop = tester.getTopLeft(headlineFinder).dy;
      final subtitleTop = tester.getTopLeft(subtitleFinder).dy;
      final createAccountTop = tester
          .getTopLeft(find.text('Create an account'))
          .dy;

      expect(headlineTop, greaterThan(symbolBottom));
      expect(subtitleTop, greaterThan(headlineTop));
      expect(createAccountTop, greaterThan(subtitleTop));

      // Gap between symbol and headline is around 38px
      expect(headlineTop - symbolBottom, closeTo(38.0, 4.0));
    },
  );

  testWidgets(
    'Welcome screen geometry remains completely stable during navigation transition',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MaterialApp(home: AuthPage()));
      await tester.pumpAndSettle();

      final symbolFinder = find.byType(Image);
      final headlineFinder = find.text('Welcome to Gufi');

      final initialSymbolTop = tester.getTopLeft(symbolFinder).dy;
      final initialHeadlineTop = tester.getTopLeft(headlineFinder).dy;

      // Tap Create an account to trigger route transition
      await tester.tap(find.text('Create an account'));

      // Pump mid-transition frame (60ms into the 170ms transition)
      await tester.pump(const Duration(milliseconds: 60));

      // The outgoing Welcome screen hero must remain geometrically frozen:
      final midSymbolTop = tester.getTopLeft(symbolFinder).dy;
      final midHeadlineTop = tester.getTopLeft(headlineFinder).dy;

      expect(midSymbolTop, equals(initialSymbolTop));
      expect(midHeadlineTop, equals(initialHeadlineTop));

      // Settle transition to destination
      await tester.pumpAndSettle();
      expect(find.text("What's your email?"), findsOneWidget);
    },
  );
}
