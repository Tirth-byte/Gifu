import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/core/services/gufi_backend_store.dart';
import 'package:gufi/core/utils/uuid_util.dart';
import 'package:gufi/features/auth/domain/models/user_profile.dart';

void main() {
  group('Circle Creation Idempotency & 6-Character Invite Code Parity', () {
    late GufiBackendStore store;
    final now = DateTime.now();
    final testUser = UserProfile(
      id: 'usr-idempotent-creator',
      email: 'creator@gufi.app',
      emailNormalized: 'creator@gufi.app',
      emailVerified: true,
      username: 'idempotent_creator',
      usernameNormalized: 'idempotent_creator',
      displayName: 'Creator',
      createdAt: now,
      updatedAt: now,
    );

    setUp(() {
      store = GufiBackendStore.instance;
      store.reset();
      store.saveUser(testUser);
      store.setCurrentSessionUser(testUser.id);
    });

    test('1. UuidUtil produces valid RFC 4122 v4 UUIDs', () {
      final uuid1 = UuidUtil.generateV4();
      final uuid2 = UuidUtil.generateV4();

      expect(uuid1, isNotEmpty);
      expect(uuid2, isNotEmpty);
      expect(uuid1, isNot(equals(uuid2)));

      final uuidV4Regex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      );
      expect(uuidV4Regex.hasMatch(uuid1), isTrue);
      expect(uuidV4Regex.hasMatch(uuid2), isTrue);
    });

    test('2. Idempotent createCircle returns existing entity on retry with same requestId', () {
      final requestId = UuidUtil.generateV4();

      // First deliberate creation action
      final circle1 = store.createCircle(
        name: 'Early Morning Club',
        ownerId: testUser.id,
        description: 'Wake up at 6am together',
        requestId: requestId,
      );

      final invites1 = store.getActiveInviteForCircle(circle1.id);
      expect(invites1, isNotNull);

      // Network retry: same owner, same request ID
      final circle2 = store.createCircle(
        name: 'Early Morning Club',
        ownerId: testUser.id,
        description: 'Wake up at 6am together',
        requestId: requestId,
      );

      // Must be the identical circle ID
      expect(circle2.id, equals(circle1.id));
      expect(circle2.name, equals(circle1.name));

      // Must not create duplicate circles in store
      final userCircles = store.getUserCircles(testUser.id);
      expect(userCircles.length, equals(1));

      // Must not create duplicate memberships
      final members = store.getCircleMembers(circle1.id);
      expect(members.length, equals(1));
    });

    test('3. Distinct requestIds create distinct circles', () {
      final req1 = UuidUtil.generateV4();
      final req2 = UuidUtil.generateV4();

      final circle1 = store.createCircle(
        name: 'Focus Sprint 1',
        ownerId: testUser.id,
        requestId: req1,
      );

      final circle2 = store.createCircle(
        name: 'Focus Sprint 2',
        ownerId: testUser.id,
        requestId: req2,
      );

      expect(circle1.id, isNot(equals(circle2.id)));
      final userCircles = store.getUserCircles(testUser.id);
      expect(userCircles.length, equals(2));
    });

    test('4. Invite code format is strictly GUFI-XXXXXX with 30-char unambiguous alphabet', () {
      final code = store.generateInviteCode();
      expect(code.startsWith('GUFI-'), isTrue);
      expect(code.length, equals(11));

      final canonicalRegex = RegExp(
        r'^GUFI-[23456789ABCDEFGHJKLMNPQRSTUVWXYZ]{6}$',
      );
      expect(canonicalRegex.hasMatch(code), isTrue);
    });

    test(
      '5. Invite code normalization handles various raw inputs and URI formats',
      () {
        expect(
          GufiBackendStore.normalizeInviteCode('GUFI-7K4PX9'),
          equals('GUFI-7K4PX9'),
        );
        expect(
          GufiBackendStore.normalizeInviteCode('7K4PX9'),
          equals('GUFI-7K4PX9'),
        );
        expect(
          GufiBackendStore.normalizeInviteCode('gufi-7k4px9'),
          equals('GUFI-7K4PX9'),
        );
        expect(
          GufiBackendStore.normalizeInviteCode('  7k4px9  '),
          equals('GUFI-7K4PX9'),
        );
        expect(
          GufiBackendStore.normalizeInviteCode('gufi://join?code=7K4PX9'),
          equals('GUFI-7K4PX9'),
        );
        expect(
          GufiBackendStore.normalizeInviteCode(
            'https://gufi.app/join/GUFI-7K4PX9?ref=share',
          ),
          equals('GUFI-7K4PX9'),
        );
      },
    );
  });
}
