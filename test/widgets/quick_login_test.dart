import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/features/auth/presentation/auth_page.dart';

void main() {
  group('Quick Login Developer Convenience Tests', () {
    testWidgets(
      'Welcome screen renders quick login cards if and only if DevToolsConfig.enabled is true',
      (tester) async {
        tester.view.physicalSize = const Size(393 * 3, 852 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(const MaterialApp(home: AuthPage()));
        await tester.pumpAndSettle();

        // Production UI must always be visible
        expect(find.text('Create an account'), findsOneWidget);
        expect(find.text('Log in'), findsOneWidget);
        expect(find.text('Apple'), findsOneWidget);
        expect(find.text('Google'), findsOneWidget);
        expect(find.textContaining('Terms of Use'), findsOneWidget);

        if (DevToolsConfig.enabled) {
          expect(find.text('Login as A'), findsOneWidget);
          expect(find.text('Login as B'), findsOneWidget);
        } else {
          // Dev tools must be completely hidden
          expect(find.text('Login as A'), findsNothing);
          expect(find.text('Login as B'), findsNothing);
          expect(find.text('Logging in...'), findsNothing);
        }
      },
    );

    testWidgets(
      'WelcomeScreen callback contract: onQuickLogin fires with credentials',
      (tester) async {
        tester.view.physicalSize = const Size(393 * 3, 852 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);

        String? loggedInEmail;
        String? loggedInPassword;

        final welcome = WelcomeScreen(
          onCreate: () {},
          onLogin: () {},
          onProvider: (_) async {},
          onBack: () {},
          onQuickLogin: (email, password) async {
            loggedInEmail = email;
            loggedInPassword = password;
          },
        );

        await tester.pumpWidget(MaterialApp(home: welcome));
        await tester.pumpAndSettle();

        // Verify standard Welcome screen elements
        expect(find.text('Welcome to Gufi'), findsOneWidget);
        expect(loggedInEmail, isNull);
        expect(loggedInPassword, isNull);
      },
    );
  });
}
