import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/core/services/gufi_backend_store.dart';
import 'package:gufi/features/commitments/domain/models/momentum_result.dart';
import 'package:gufi/features/commitments/domain/models/proof_type.dart';
import 'package:gufi/features/commitments/domain/models/review.dart';

void main() {
  setUp(() {
    GufiBackendStore.instance.reset();
  });

  group('Momentum V1 Calculation & Rules', () {
    test(
      'Formula: 13 verified, 1 missed, 1 cancelled = 86.7% -> rounds to 87',
      () {
        final result = MomentumResult.fromCounts(
          verified: 13,
          missed: 1,
          cancelled: 1,
        );

        expect(result.isAvailable, isTrue);
        expect(result.verifiedCount, 13);
        expect(result.missedCount, 1);
        expect(result.cancelledCount, 1);
        expect(result.resolvedCount, 15);
        expect(result.score, 87); // (13 / 15) * 100 = 86.666... -> 87
      },
    );

    test('Zero resolved commitments returns neutral/unavailable state instead of fake 100%', () {
      final result = MomentumResult.fromCounts(
        verified: 0,
        missed: 0,
        cancelled: 0,
      );

      expect(result.isAvailable, isFalse);
      expect(result.score, isNull);
      expect(result.resolvedCount, 0);
    });

    test('Pending review commitments do NOT count against momentum', () {
      final store = GufiBackendStore.instance;
      const day = '2026-10-16';

      // 2 verified
      for (int i = 1; i <= 2; i++) {
        final d = store.createDraftCommitment(
          ownerId: 'user-tirth',
          title: 'Verified $i',
          proofType: ProofType.text,
          gufiDay: day,
          dueAt: DateTime.now().add(const Duration(hours: 6)),
        );
        store.commitCommitment(d.id);
        final p = store.submitProof(
          commitmentId: d.id,
          submitterId: 'user-tirth',
          proofType: ProofType.text,
          textContent: 'done',
        );
        store.reviewProof(
          proofId: p.id,
          reviewerId: 'admin-verifier',
          decision: ReviewDecision.approved,
        );
      }

      // 1 still pending review
      final dPending = store.createDraftCommitment(
        ownerId: 'user-tirth',
        title: 'Pending review',
        proofType: ProofType.text,
        gufiDay: day,
        dueAt: DateTime.now().add(const Duration(hours: 6)),
      );
      store.commitCommitment(dPending.id);
      store.submitProof(
        commitmentId: dPending.id,
        submitterId: 'user-tirth',
        proofType: ProofType.text,
        textContent: 'submitted',
      );

      final momentum = store.getMomentum(
        userId: 'user-tirth',
        currentGufiDay: day,
      );

      // Pending is NOT resolved, so resolvedCount is 2, verified is 2 -> 100%
      expect(momentum.verifiedCount, 2);
      expect(momentum.resolvedCount, 2);
      expect(momentum.score, 100);
    });

    test(
      'Cancelled commitment counts as NOT KEPT (included in denominator)',
      () {
        final store = GufiBackendStore.instance;
        const day = '2026-10-16';

        // 1 verified
        final d1 = store.createDraftCommitment(
          ownerId: 'user-tirth',
          title: 'Verified 1',
          proofType: ProofType.text,
          gufiDay: day,
          dueAt: DateTime.now().add(const Duration(hours: 6)),
        );
        store.commitCommitment(d1.id);
        final p1 = store.submitProof(
          commitmentId: d1.id,
          submitterId: 'user-tirth',
          proofType: ProofType.text,
          textContent: 'done',
        );
        store.reviewProof(
          proofId: p1.id,
          reviewerId: 'admin-verifier',
          decision: ReviewDecision.approved,
        );

        // 1 cancelled
        final d2 = store.createDraftCommitment(
          ownerId: 'user-tirth',
          title: 'Cancelled 1',
          proofType: ProofType.text,
          gufiDay: day,
          dueAt: DateTime.now().add(const Duration(hours: 6)),
        );
        store.commitCommitment(d2.id);
        store.cancelCommitment(commitmentId: d2.id, ownerId: 'user-tirth');

        final momentum = store.getMomentum(
          userId: 'user-tirth',
          currentGufiDay: day,
        );

        // 1 verified / 2 resolved = 50%
        expect(momentum.verifiedCount, 1);
        expect(momentum.cancelledCount, 1);
        expect(momentum.resolvedCount, 2);
        expect(momentum.score, 50);
      },
    );

    test('Commitments outside the 7-day window are excluded', () {
      final store = GufiBackendStore.instance;
      const currentDay = '2026-10-16';

      // Commitment from 10 days ago (2026-10-06)
      final oldDraft = store.createDraftCommitment(
        ownerId: 'user-tirth',
        title: 'Old Verified',
        proofType: ProofType.text,
        gufiDay: '2026-10-06',
        dueAt: DateTime.parse('2026-10-06T20:00:00Z'),
      );
      store.commitCommitment(oldDraft.id);
      final oldProof = store.submitProof(
        commitmentId: oldDraft.id,
        submitterId: 'user-tirth',
        proofType: ProofType.text,
        textContent: 'done',
      );
      store.reviewProof(
        proofId: oldProof.id,
        reviewerId: 'admin-verifier',
        decision: ReviewDecision.approved,
      );

      // In the 7-day window (2026-10-10 to 2026-10-16): 0 resolved
      final momentum = store.getMomentum(
        userId: 'user-tirth',
        currentGufiDay: currentDay,
      );

      expect(momentum.isAvailable, isFalse);
      expect(momentum.resolvedCount, 0);
    });
  });
}
