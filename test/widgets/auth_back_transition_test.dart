import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/features/auth/presentation/auth_page.dart';

void main() {
  setUp(() {
    FocusManager.instance.primaryFocus?.unfocus();
  });

  testWidgets(
    'Login email screen: keyboard open -> tap Back -> unfocuses immediately and Welcome screen remains stationary',
    (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MaterialApp(home: AuthPage()));
      await tester.pumpAndSettle();

      // 1. Record Welcome screen exact resting positions
      final heroPosBefore = tester.getTopLeft(find.text('Welcome to Gufi'));
      final createBtnPosBefore = tester.getTopLeft(
        find.text('Create an account'),
      );
      final loginBtnPosBefore = tester.getTopLeft(find.text('Log in'));

      // 2. Navigate to Log in
      await tester.tap(find.text('Log in'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back.'), findsOneWidget);

      // 3. Focus email field so keyboard opens
      final emailField = find.byType(TextField);
      await tester.tap(emailField);
      await tester.pump();

      // Verify text field has focus
      expect(FocusScope.of(tester.element(emailField)).focusedChild, isNotNull);

      // Simulate iOS keyboard appearance
      tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();

      // 4. Tap back arrow
      final backButton = find.bySemanticsLabel('Back');
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);

      // Immediately after tapping back, input focus MUST be dismissed
      final primaryFocus = FocusManager.instance.primaryFocus;
      expect(primaryFocus?.context?.widget is! EditableText, isTrue);

      // 5. During transition with keyboard dismissing
      tester.view.viewInsets = const FakeViewPadding(bottom: 200 * 3);
      await tester.pump(const Duration(milliseconds: 50));

      tester.view.viewInsets = const FakeViewPadding(bottom: 60 * 3);
      await tester.pump(const Duration(milliseconds: 50));

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      // 6. Verify Welcome screen is back in exact same positions
      expect(find.text('Welcome to Gufi'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Welcome to Gufi')),
        equals(heroPosBefore),
      );
      expect(
        tester.getTopLeft(find.text('Create an account')),
        equals(createBtnPosBefore),
      );
      expect(tester.getTopLeft(find.text('Log in')), equals(loginBtnPosBefore));
    },
  );

  testWidgets(
    'Create Account email screen: keyboard open -> tap Back -> unfocuses immediately and Welcome screen remains stationary',
    (tester) async {
      tester.view.physicalSize = const Size(393 * 3, 852 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const MaterialApp(home: AuthPage()));
      await tester.pumpAndSettle();

      final heroPosBefore = tester.getTopLeft(find.text('Welcome to Gufi'));
      final createBtnPosBefore = tester.getTopLeft(
        find.text('Create an account'),
      );
      final loginBtnPosBefore = tester.getTopLeft(find.text('Log in'));

      // 1. Navigate to Create account
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();
      expect(find.text("What's your email?"), findsOneWidget);

      // 2. Focus email field so keyboard opens
      final emailField = find.byType(TextField);
      await tester.tap(emailField);
      await tester.pump();

      expect(FocusScope.of(tester.element(emailField)).focusedChild, isNotNull);

      // Simulate iOS keyboard appearance
      tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();

      // 3. Tap back arrow
      final backButton = find.bySemanticsLabel('Back');
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);

      // Focus immediately dismissed
      final primaryFocus = FocusManager.instance.primaryFocus;
      expect(primaryFocus?.context?.widget is! EditableText, isTrue);

      // 4. Keyboard dismissing during transition
      tester.view.viewInsets = const FakeViewPadding(bottom: 150 * 3);
      await tester.pump(const Duration(milliseconds: 75));

      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();

      // 5. Verify Welcome screen is back in exact same positions
      expect(find.text('Welcome to Gufi'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Welcome to Gufi')),
        equals(heroPosBefore),
      );
      expect(
        tester.getTopLeft(find.text('Create an account')),
        equals(createBtnPosBefore),
      );
      expect(tester.getTopLeft(find.text('Log in')), equals(loginBtnPosBefore));
    },
  );

  testWidgets('Back navigation when keyboard is already closed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: AuthPage()));
    await tester.pumpAndSettle();

    final heroPosBefore = tester.getTopLeft(find.text('Welcome to Gufi'));

    // Flow 1: Login back
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Gufi'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Welcome to Gufi')),
      equals(heroPosBefore),
    );

    // Flow 2: Create account back
    await tester.tap(find.text('Create an account'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Gufi'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Welcome to Gufi')),
      equals(heroPosBefore),
    );
  });
}
