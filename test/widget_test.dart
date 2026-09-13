import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/app/app.dart';
import 'package:gufi/features/onboarding/presentation/components/circular_arrow_button.dart';
import 'package:gufi/features/onboarding/presentation/onboarding_page.dart';

void main() {
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
}
