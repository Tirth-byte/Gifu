import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/core/services/gufi_backend_store.dart';
import 'package:gufi/features/commitments/domain/models/commitment_status.dart';
import 'package:gufi/features/commitments/domain/models/proof_type.dart';

void main() {
  setUp(() {
    GufiBackendStore.instance.reset();
  });

  group('Maximum 3 Commitments per Gufi Day Enforcement', () {
    test('User can commit up to 3 commitments on a single Gufi day', () {
      final store = GufiBackendStore.instance;
      const day = '2026-10-16';

      final d1 = store.createDraftCommitment(
        ownerId: 'user-tirth',
        title: 'Commitment 1',
        proofType: ProofType.text,
        gufiDay: day,
        dueAt: DateTime.now().add(const Duration(hours: 6)),
      );
      final d2 = store.createDraftCommitment(
        ownerId: 'user-tirth',
        title: 'Commitment 2',
        proofType: ProofType.text,
        gufiDay: day,
        dueAt: DateTime.now().add(const Duration(hours: 6)),
      );
      final d3 = store.createDraftCommitment(
        ownerId: 'user-tirth',
        title: 'Commitment 3',
        proofType: ProofType.text,
        gufiDay: day,
        dueAt: DateTime.now().add(const Duration(hours: 6)),
      );

      final c1 = store.commitCommitment(d1.id);
      final c2 = store.commitCommitment(d2.id);
      final c3 = store.commitCommitment(d3.id);

      expect(c1.status, CommitmentStatus.committed);
      expect(c2.status, CommitmentStatus.committed);
      expect(c3.status, CommitmentStatus.committed);
    });

    test(
      '4th commitment on the same Gufi day is rejected with daily limit error',
      () {
        final store = GufiBackendStore.instance;
        const day = '2026-10-16';

        // Commit 3 items
        for (int i = 1; i <= 3; i++) {
          final d = store.createDraftCommitment(
            ownerId: 'user-tirth',
            title: 'Commitment $i',
            proofType: ProofType.text,
            gufiDay: day,
            dueAt: DateTime.now().add(const Duration(hours: 6)),
          );
          store.commitCommitment(d.id);
        }

        // 4th draft creation is allowed
        final d4 = store.createDraftCommitment(
          ownerId: 'user-tirth',
          title: 'Commitment 4',
          proofType: ProofType.text,
          gufiDay: day,
          dueAt: DateTime.now().add(const Duration(hours: 6)),
        );
        expect(d4.status, CommitmentStatus.draft);

        // Attempting to commit 4th commitment must throw
        expect(
          () => store.commitCommitment(d4.id),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Daily limit reached: maximum 3 commitments'),
            ),
          ),
        );
      },
    );

    test('Drafts do NOT count towards the 3-commitment limit', () {
      final store = GufiBackendStore.instance;
      const day = '2026-10-16';

      // Create 5 drafts
      final drafts = List.generate(
        5,
        (i) => store.createDraftCommitment(
          ownerId: 'user-tirth',
          title: 'Draft $i',
          proofType: ProofType.text,
          gufiDay: day,
          dueAt: DateTime.now().add(const Duration(hours: 6)),
        ),
      );

      expect(drafts.length, 5);

      // Can commit any 3 of them
      store.commitCommitment(drafts[0].id);
      store.commitCommitment(drafts[1].id);
      store.commitCommitment(drafts[2].id);

      // 4th commit fails
      expect(() => store.commitCommitment(drafts[3].id), throwsStateError);
    });

    test('Next Gufi day has fresh 3-commitment quota', () {
      final store = GufiBackendStore.instance;

      // 3 on Oct 16
      for (int i = 1; i <= 3; i++) {
        final d = store.createDraftCommitment(
          ownerId: 'user-tirth',
          title: 'Day 1 Commitment $i',
          proofType: ProofType.text,
          gufiDay: '2026-10-16',
          dueAt: DateTime.now().add(const Duration(hours: 6)),
        );
        store.commitCommitment(d.id);
      }

      // New commitment on Oct 17 is allowed
      final nextDayDraft = store.createDraftCommitment(
        ownerId: 'user-tirth',
        title: 'Day 2 Commitment 1',
        proofType: ProofType.text,
        gufiDay: '2026-10-17',
        dueAt: DateTime.now().add(const Duration(hours: 24)),
      );

      final nextDayCommitted = store.commitCommitment(nextDayDraft.id);
      expect(nextDayCommitted.status, CommitmentStatus.committed);
    });
  });
}
