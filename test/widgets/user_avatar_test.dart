import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/core/widgets/account_action_button.dart';
import 'package:gufi/core/widgets/user_avatar.dart';
import 'package:gufi/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:gufi/features/auth/domain/models/user_profile.dart';

void main() {
  group('UserAvatar Widget Tests', () {
    testWidgets('renders NetworkImage when photoUrl is populated', (
      WidgetTester tester,
    ) async {
      const testUrl =
          'https://npgaqtxcjjqbyksjmpar.supabase.co/storage/v1/object/public/avatars/usr-1/avatar_123.jpg';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(photoUrl: testUrl, fallbackInitial: 'A', size: 40),
          ),
        ),
      );

      // Verify that Image widget is rendered with the expected NetworkImage URL
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<NetworkImage>());
      expect((imageWidget.image as NetworkImage).url, equals(testUrl));

      // Verify fallback initial is NOT rendered when photoUrl is valid
      expect(find.text('A'), findsNothing);
    });

    testWidgets('renders fallback initial when photoUrl is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(photoUrl: null, fallbackInitial: 'A', size: 40),
          ),
        ),
      );

      // Verify no Image widget
      expect(find.byType(Image), findsNothing);

      // Verify initial is rendered
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets(
      'renders fallback initial when photoUrl is empty or whitespace',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(photoUrl: '   ', fallbackInitial: 'Z', size: 40),
            ),
          ),
        );

        // Verify no Image widget
        expect(find.byType(Image), findsNothing);

        // Verify initial is rendered
        expect(find.text('Z'), findsOneWidget);
      },
    );
  });

  group('AccountActionButton Integration Tests', () {
    final authRepo = SupabaseAuthRepository.instance;

    setUp(() {
      authRepo.setSessionForTesting(null);
    });

    testWidgets(
      'renders NetworkImage when current user has profilePhotoUrl populated',
      (WidgetTester tester) async {
        final profileWithPhoto = UserProfile(
          id: 'usr-avatar-1',
          email: 'avatar@gufi.app',
          emailNormalized: 'avatar@gufi.app',
          emailVerified: true,
          username: 'avatarguy',
          usernameNormalized: 'avatarguy',
          displayName: 'Avatar Guy',
          profilePhotoUrl: 'https://npgaqtxcjjqbyksjmpar.supabase.co/storage/v1/object/public/avatars/usr-avatar-1/avatar.jpg',
          profileComplete: true,
          onboardingCompleted: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        authRepo.setSessionForTesting(profileWithPhoto);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: AccountActionButton())),
        );

        // Verify Image is rendered
        final imageFinder = find.byType(Image);
        expect(imageFinder, findsOneWidget);
        final imageWidget = tester.widget<Image>(imageFinder);
        expect(imageWidget.image, isA<NetworkImage>());
        expect(
          (imageWidget.image as NetworkImage).url,
          equals(profileWithPhoto.profilePhotoUrl),
        );
        expect(find.text('A'), findsNothing);
      },
    );

    testWidgets(
      'renders initial fallback when current user has no profilePhotoUrl',
      (WidgetTester tester) async {
        final profileWithoutPhoto = UserProfile(
          id: 'usr-avatar-2',
          email: 'noavatar@gufi.app',
          emailNormalized: 'noavatar@gufi.app',
          emailVerified: true,
          username: 'noavatar',
          usernameNormalized: 'noavatar',
          displayName: 'No Avatar',
          profilePhotoUrl: null,
          profileComplete: true,
          onboardingCompleted: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        authRepo.setSessionForTesting(profileWithoutPhoto);

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: AccountActionButton())),
        );

        // Verify fallback initial is rendered
        expect(find.byType(Image), findsNothing);
        expect(find.text('N'), findsOneWidget);
      },
    );
  });
}
