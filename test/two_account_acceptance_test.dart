import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/core/config/app_config.dart';
import 'package:gufi/core/services/app_preferences_service.dart';
import 'package:gufi/core/services/gufi_backend_store.dart';
import 'package:gufi/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:gufi/features/auth/domain/models/user_profile.dart';
import 'package:gufi/features/circles/data/repositories/supabase_circle_repository.dart';
import 'package:gufi/features/circles/domain/models/circle_invite.dart';

void main() {
  final store = GufiBackendStore.instance;
  final authRepo = SupabaseAuthRepository.instance;
  final circleRepo = SupabaseCircleRepository.instance;

  final now = DateTime.utc(2026, 10, 17);

  final accountA = UserProfile(
    id: 'usr-account-a',
    email: 'account.a@example.com',
    emailNormalized: 'account.a@example.com',
    emailVerified: true,
    username: 'account_a',
    usernameNormalized: 'account_a',
    displayName: 'Account A',
    onboardingCompleted: true,
    role: 'user',
    createdAt: now,
    updatedAt: now,
  );

  final accountB = UserProfile(
    id: 'usr-account-b',
    email: 'account.b@example.com',
    emailNormalized: 'account.b@example.com',
    emailVerified: true,
    username: 'account_b',
    usernameNormalized: 'account_b',
    displayName: 'Account B',
    onboardingCompleted: true,
    role: 'user',
    createdAt: now,
    updatedAt: now,
  );

  setUp(() {
    AppPreferencesService.instance.resetForTesting();
    store.reset();
    authRepo.signOut();
  });

  test('FULL TWO-ACCOUNT ACCEPTANCE TEST (Part S & End-to-End Flow)', () async {
    // -----------------------------------------------------------------
    // 1. Account A logs in
    // -----------------------------------------------------------------
    authRepo.setSessionForTesting(accountA);
    expect(authRepo.currentUserProfile?.id, equals(accountA.id));

    // -----------------------------------------------------------------
    // 2. Account A creates Circle "Morning Momentum"
    // -----------------------------------------------------------------
    final createdCircle = await circleRepo.createCircle(
      name: 'Morning Momentum',
      ownerId: accountA.id,
      description: 'Daily consistency and focus',
    );
    expect(createdCircle.name, equals('Morning Momentum'));
    expect(createdCircle.ownerId, equals(accountA.id));

    // -----------------------------------------------------------------
    // 3. Confirm active membership for Account A
    // -----------------------------------------------------------------
    final membersAfterCreation = await circleRepo.getCircleMembers(
      createdCircle.id,
    );
    expect(membersAfterCreation.length, equals(1));
    expect(membersAfterCreation.first.userId, equals(accountA.id));

    // -----------------------------------------------------------------
    // 4. Confirm real backend invite code exists and is canonical
    // -----------------------------------------------------------------
    final invite = await circleRepo.getActiveInviteForCircle(createdCircle.id);
    expect(invite, isNotNull);
    final canonicalCode = invite!.code;
    expect(canonicalCode.startsWith('GUFI-'), isTrue);
    expect(canonicalCode.length, equals(11));
    expect(
      RegExp(r'^GUFI-[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{6}$')
          .hasMatch(canonicalCode),
      isTrue,
    );

    // Verify invite link does NOT emit broken domain
    final inviteLink = AppConfig.buildInviteLink(canonicalCode);
    expect(inviteLink.contains('gufi.app'), isFalse);
    expect(inviteLink, equals('gufi://join?code=$canonicalCode'));

    final shareText = AppConfig.buildShareText(
      circleName: createdCircle.name,
      code: canonicalCode,
    );
    expect(shareText.contains('gufi.app'), isFalse);
    expect(shareText.contains(canonicalCode), isTrue);
    expect(shareText.contains('gufi://join?code=$canonicalCode'), isTrue);

    // -----------------------------------------------------------------
    // 5. Account A logs out
    // -----------------------------------------------------------------
    await authRepo.signOut();
    expect(authRepo.currentUserProfile, isNull);
    expect(store.currentSessionUserId, isNull);

    // -----------------------------------------------------------------
    // 6. Account B logs in
    // -----------------------------------------------------------------
    authRepo.setSessionForTesting(accountB);
    expect(authRepo.currentUserProfile?.id, equals(accountB.id));

    // -----------------------------------------------------------------
    // 7. Account B resolves invite with various formatting:
    //    lowercase, extra spaces, deep link URI
    // -----------------------------------------------------------------
    final formattedInputs = [
      canonicalCode,
      canonicalCode.toLowerCase(),
      '  $canonicalCode  ',
      canonicalCode.replaceAll('-', ' '),
      'gufi://join?code=$canonicalCode',
    ];

    for (final input in formattedInputs) {
      final resolution = await circleRepo.resolveInvite(
        code: input,
        currentUserId: accountB.id,
      );
      expect(
        resolution,
        isA<InviteResolvedValid>(),
        reason: 'Failed to resolve formatted code: $input',
      );
      final valid = resolution as InviteResolvedValid;
      expect(valid.preview.circleName, equals('Morning Momentum'));
      expect(valid.preview.memberCount, equals(1));
    }

    // -----------------------------------------------------------------
    // 8. Account B joins the Circle
    // -----------------------------------------------------------------
    final joinResult = await circleRepo.joinCircleWithInvite(
      code: canonicalCode,
      userId: accountB.id,
    );
    expect(joinResult, isA<JoinCircleSuccess>());

    // Verify membership count is now 2
    final membersAfterJoin = await circleRepo.getCircleMembers(
      createdCircle.id,
    );
    expect(membersAfterJoin.length, equals(2));
    expect(
      membersAfterJoin.map((m) => m.userId),
      containsAll([accountA.id, accountB.id]),
    );

    // Re-resolving by Account B now structured as already_member
    final reResolve = await circleRepo.resolveInvite(
      code: canonicalCode,
      currentUserId: accountB.id,
    );
    expect(reResolve, isA<InviteResolvedAlreadyMember>());

    // -----------------------------------------------------------------
    // 9. Account B logs out
    // -----------------------------------------------------------------
    await authRepo.signOut();
    expect(authRepo.currentUserProfile, isNull);

    // -----------------------------------------------------------------
    // 10. Account A logs back in
    // -----------------------------------------------------------------
    authRepo.setSessionForTesting(accountA);
    expect(authRepo.currentUserProfile?.id, equals(accountA.id));

    // Verify Account A sees updated circle with >= 2 members (Ready State)
    final circlesForA = await circleRepo.getUserCircles(accountA.id);
    expect(circlesForA.length, equals(1));
    final circleA = circlesForA.first;
    final membersForA = await circleRepo.getCircleMembers(circleA.id);
    expect(membersForA.length, greaterThanOrEqualTo(2));

    // -----------------------------------------------------------------
    // 11. Simulate app close & reopen (Session restore)
    // -----------------------------------------------------------------
    // Cached profile cleared from memory
    final restoredProfile = await authRepo.restoreSession();
    expect(restoredProfile, isNotNull);
    expect(restoredProfile!.id, equals(accountA.id));

    // Active memberships restored
    final restoredCircles = await circleRepo.getUserCircles(restoredProfile.id);
    expect(restoredCircles.isNotEmpty, isTrue);
    final restoredMembers = await circleRepo.getCircleMembers(
      restoredCircles.first.id,
    );
    expect(restoredMembers.length, greaterThanOrEqualTo(2));
  });
}
