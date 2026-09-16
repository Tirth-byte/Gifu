import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/core/services/gufi_backend_store.dart';
import 'package:gufi/features/admin/data/repositories/supabase_admin_repository.dart';
import 'package:gufi/features/auth/data/repositories/supabase_auth_repository.dart';

void main() {
  setUp(() {
    GufiBackendStore.instance.reset();
  });

  group('End-to-End Real Auth + Admin Pipeline (Zero Fake Data)', () {
    test(
      'Initial database is completely clean with 0 users and 0 audit logs',
      () async {
        final adminRepo = SupabaseAdminRepository();

        final metrics = await adminRepo.fetchMetrics();
        expect(metrics['total'], 0);
        expect(metrics['verified'], 0);
        expect(metrics['newToday'], 0);
        expect(metrics['completed'], 0);

        final users = await adminRepo.fetchUsers();
        expect(users.isEmpty, isTrue);

        final auditLogs = await adminRepo.fetchAuditLogs();
        expect(auditLogs.isEmpty, isTrue);
      },
    );

    test(
      'Creating a real account propagates to Single Source of Truth',
      () async {
        final authRepo = SupabaseAuthRepository.instance;
        final adminRepo = SupabaseAdminRepository();

        // Step 1: Sign up and complete user profile
        await authRepo.signUpWithEmailAndPassword(
          email: 'tirth@gufi.app',
          password: 'SecretPassword123!',
        );
        final profile = await authRepo.completeUserProfile(
          username: 'tirth09',
          displayName: 'Tirth Patel',
        );

        expect(profile.username, 'tirth09');
        expect(profile.displayName, 'Tirth Patel');
        expect(profile.email, 'tirth@gufi.app');

        // Step 2: Verify Coming Soon / Auth session reads the exact same user
        final currentSessionUser = authRepo.currentUserProfile;
        expect(currentSessionUser, isNotNull);
        expect(currentSessionUser!.username, 'tirth09');

        // Step 3: Verify Admin Overview reflects this real user
        final metrics = await adminRepo.fetchMetrics();
        expect(metrics['total'], 1);
        expect(metrics['verified'], 1);
        expect(metrics['newToday'], 1);
        expect(metrics['password'], 1);

        // Step 4: Verify Admin Database Grid queries this user
        final users = await adminRepo.fetchUsers();
        expect(users.length, 1);
        final adminUser = users.first;
        expect(adminUser.username, 'tirth09');
        expect(adminUser.email, 'tirth@gufi.app');
        expect(adminUser.accountStatus, 'active');

        // Step 5: Search functionality finds the user
        final searchFound = await adminRepo.fetchUsers(query: 'tirth');
        expect(searchFound.length, 1);
        final searchNotFound = await adminRepo.fetchUsers(query: 'nonexistent');
        expect(searchNotFound.isEmpty, isTrue);

        // Step 6: Filter functionality
        final filteredEmail = await adminRepo.fetchUsers(filter: 'Verified');
        expect(filteredEmail.length, 1);
        final filteredDisabled = await adminRepo.fetchUsers(filter: 'Disabled');
        expect(filteredDisabled.isEmpty, isTrue);

        // Step 7: Admin disables account -> audit log created
        await adminRepo.setUserStatus(
          targetUserId: adminUser.id,
          status: 'disabled',
        );
        final updatedUsers = await adminRepo.fetchUsers();
        expect(updatedUsers.first.accountStatus, 'disabled');

        final logs = await adminRepo.fetchAuditLogs();
        expect(logs.length, 1);
        expect(logs.first.action, 'USER_DISABLED');
        expect(logs.first.humanAction, 'Disabled user');

        // Step 8: Export Users CSV respects security and includes safe fields
        final csv = await adminRepo.exportUsersCsv();
        expect(csv, contains('tirth09'));
        expect(csv, contains('tirth@gufi.app'));
        expect(csv, contains('disabled'));
        expect(
          csv.contains('SecretPassword123!'),
          isFalse,
        ); // No passwords exported

        // Step 9: Re-enable user
        await adminRepo.setUserStatus(
          targetUserId: adminUser.id,
          status: 'active',
        );
        final reLogs = await adminRepo.fetchAuditLogs();
        expect(reLogs.length, 3); // USER_DISABLED, USERS_EXPORTED, USER_ENABLED
        expect(reLogs.first.action, 'USER_ENABLED');
        expect(reLogs.first.humanAction, 'Enabled user');
      },
    );
  });
}
