import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/core/services/disposable_email_service.dart';
import 'package:gufi/core/services/csv_export_service.dart';
import 'package:gufi/features/admin/domain/models/admin_user_summary.dart';

void main() {
  group('DisposableEmailService', () {
    test('normalizes email addresses correctly', () {
      expect(
        DisposableEmailService.normalizeEmail('  John.Doe@GMAIL.COM  '),
        equals('John.Doe@gmail.com'),
      );
      expect(
        DisposableEmailService.normalizeEmail('User@Company.Org'),
        equals('User@company.org'),
      );
    });

    test('extracts domain correctly', () {
      expect(
        DisposableEmailService.extractDomain('test@mailinator.com'),
        equals('mailinator.com'),
      );
      expect(
        DisposableEmailService.extractDomain('user@privaterelay.appleid.com'),
        equals('privaterelay.appleid.com'),
      );
    });

    test('identifies and rejects known disposable email domains', () {
      expect(
        DisposableEmailService.isDisposable('temp@mailinator.com'),
        isTrue,
      );
      expect(
        DisposableEmailService.isDisposable('anon@10minutemail.com'),
        isTrue,
      );
      expect(DisposableEmailService.isDisposable('junk@tempmail.com'), isTrue);
      expect(
        DisposableEmailService.isDisposable('throw@guerrillamail.com'),
        isTrue,
      );
      expect(DisposableEmailService.isDisposable('spam@yopmail.com'), isTrue);
    });

    test('preserves legitimate domains including universities, companies, and Apple Private Relay', () {
      expect(
        DisposableEmailService.isDisposable('student@stanford.edu'),
        isFalse,
      );
      expect(
        DisposableEmailService.isDisposable('engineer@company.io'),
        isFalse,
      );
      expect(DisposableEmailService.isDisposable('tirth@gmail.com'), isFalse);
      expect(DisposableEmailService.isDisposable('user@icloud.com'), isFalse);
      // Critical requirement: Apple Private Relay must NOT be rejected
      expect(
        DisposableEmailService.isDisposable('xyz123@privaterelay.appleid.com'),
        isFalse,
      );
    });

    test('validates syntax correctly', () {
      expect(DisposableEmailService.isValidSyntax('hello@gufi.app'), isTrue);
      expect(DisposableEmailService.isValidSyntax('invalid-email'), isFalse);
      expect(DisposableEmailService.isValidSyntax('@domain.com'), isFalse);
    });
  });

  group('CsvExportService', () {
    test(
      'generates valid RFC-4180 CSV with Excel UTF-8 BOM and safe fields only',
      () {
        final users = [
          AdminUserSummary(
            id: 'usr-001',
            email: 'tirth@gufi.app',
            emailNormalized: 'tirth@gufi.app',
            emailVerified: true,
            username: 'tirth',
            usernameNormalized: 'tirth',
            displayName: 'Tirth',
            authProvider: 'email',
            profilePhotoUrl: 'https://example.com/avatar.jpg',
            onboardingCompleted: true,
            accountStatus: 'active',
            role: 'admin',
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              1700000000000,
              isUtc: true,
            ),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
              1700001000000,
              isUtc: true,
            ),
          ),
          AdminUserSummary(
            id: 'usr-002',
            email: 'alice@company.com',
            emailNormalized: 'alice@company.com',
            emailVerified: false,
            username: 'alice_smith',
            usernameNormalized: 'alice_smith',
            displayName: 'Alice "Wonder" Smith',
            authProvider: 'google',
            profilePhotoUrl: null,
            onboardingCompleted: false,
            accountStatus: 'active',
            role: 'user',
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              1700000000000,
              isUtc: true,
            ),
            updatedAt: DateTime.fromMillisecondsSinceEpoch(
              1700000000000,
              isUtc: true,
            ),
          ),
        ];

        final userMaps = users.map((u) => u.toJson()).toList();
        final csv = CsvExportService.generateUsersCsv(userMaps);

        // Must start with UTF-8 BOM for Excel
        expect(csv.startsWith('\uFEFF'), isTrue);

        // Must have safe headers
        expect(
          csv,
          contains(
            '"User ID","Email","Email Verified","Username","Display Name","Auth Provider","Profile Photo Present","Onboarding Completed","Account Status","Role","Created At (UTC)","Updated At (UTC)"',
          ),
        );

        // Must escape quotes properly
        expect(csv, contains('"Alice ""Wonder"" Smith"'));

        // MUST NEVER leak passwords or tokens
        expect(csv.toLowerCase(), isNot(contains('password')));
        expect(csv.toLowerCase(), isNot(contains('hash')));
        expect(csv.toLowerCase(), isNot(contains('secret')));

        // Verifies safe fields
        expect(csv, contains('tirth@gufi.app'));
        expect(csv, contains('alice@company.com'));
        expect(csv, contains('admin'));
      },
    );
  });
}
