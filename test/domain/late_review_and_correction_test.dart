import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/core/services/gufi_backend_store.dart';
import 'package:gufi/features/commitments/domain/models/commitment_status.dart';
import 'package:gufi/features/commitments/domain/models/proof.dart';
import 'package:gufi/features/commitments/domain/models/proof_type.dart';
import 'package:gufi/features/commitments/domain/models/review.dart';

void main() {
  setUp(() {
    GufiBackendStore.instance.reset();
  });

  group('Late Review & Correction Window Invariants', () {
    test('On-time proof submission is NOT marked missed when reviewed after deadline', () {
      final store = GufiBackendStore.instance;
      final deadline = DateTime.utc(2026, 10, 16, 20, 0, 0);

      // Commitment due at 20:00 UTC
      final draft = store.createDraftCommitment(
        ownerId: 'user-alice',
        title: 'Drink 2L water',
        proofType: ProofType.text,
        gufiDay: '2026-10-16',
        dueAt: deadline,
      );
      final committed = store.commitCommitment(draft.id);

      // User submits proof on-time at 19:30 UTC
      final proof = store.submitProof(
        commitmentId: committed.id,
        submitterId: 'user-alice',
        proofType: ProofType.text,
        textContent: 'Drank 2.5L total',
        nowOverride: DateTime.utc(2026, 10, 16, 19, 30, 0),
      );
      expect(proof.submittedAt.isBefore(deadline), isTrue);

      // Next morning at 09:00 UTC (13 hours past deadline)
      final nextMorning = DateTime.utc(2026, 10, 17, 9, 0, 0);

      // Server sweep runs
      final missedSweepCount = store.evaluateMissedCommitments(
        nowOverride: nextMorning,
      );
      expect(missedSweepCount, 0);

      // Commitment status remains PROOF_SUBMITTED (not missed!)
      final commAfterSweep = store.getCommitment(committed.id)!;
      expect(commAfterSweep.status, CommitmentStatus.proofSubmitted);

      // Reviewer approves the next morning
      store.reviewProof(
        proofId: proof.id,
        reviewerId: 'user-verifier',
        decision: ReviewDecision.approved,
        nowOverride: nextMorning,
      );

      final verifiedComm = store.getCommitment(committed.id)!;
      expect(verifiedComm.status, CommitmentStatus.verified);
    });

    test('Rejection of on-time proof gives 6-hour correction window; resubmission succeeds', () {
      final store = GufiBackendStore.instance;
      final deadline = DateTime.utc(2026, 10, 16, 20, 0, 0);

      final draft = store.createDraftCommitment(
        ownerId: 'user-alice',
        title: 'Pushups 50',
        proofType: ProofType.photo,
        gufiDay: '2026-10-16',
        dueAt: deadline,
      );
      final committed = store.commitCommitment(draft.id);

      // Proof submitted on-time
      final proof = store.submitProof(
        commitmentId: committed.id,
        submitterId: 'user-alice',
        proofType: ProofType.photo,
        mediaUrl: 'https://storage.gufi.app/proofs/pushups.jpg',
        nowOverride: DateTime.utc(2026, 10, 16, 19, 30, 0),
      );

      // Reviewer rejects after deadline
      final review = store.reviewProof(
        proofId: proof.id,
        reviewerId: 'user-verifier',
        decision: ReviewDecision.rejected,
        reason: 'Photo is blurry',
      );
      expect(review.isRejected, isTrue);

      final rejectedComm = store.getCommitment(committed.id)!;
      expect(rejectedComm.status, CommitmentStatus.rejected);
      expect(rejectedComm.correctionDeadline, isNotNull);

      // Correction deadline is set to ~6 hours from rejection
      final expectedMinDeadline = DateTime.now().add(
        const Duration(hours: 5, minutes: 59),
      );
      expect(
        rejectedComm.correctionDeadline!.isAfter(expectedMinDeadline),
        isTrue,
      );

      // Alice resubmits clear photo before correction deadline
      final resubmittedProof = store.submitProof(
        commitmentId: committed.id,
        submitterId: 'user-alice',
        proofType: ProofType.photo,
        mediaUrl: 'https://storage.gufi.app/proofs/pushups_clear.jpg',
      );
      expect(resubmittedProof.status, ProofStatus.submitted);

      final resubmittedComm = store.getCommitment(committed.id)!;
      expect(resubmittedComm.status, CommitmentStatus.proofSubmitted);
      expect(resubmittedComm.correctionDeadline, isNull);
    });

    test('If correction window expires without resubmission, commitment becomes MISSED', () {
      final store = GufiBackendStore.instance;
      final draft = store.createDraftCommitment(
        ownerId: 'user-alice',
        title: 'Run 5km',
        proofType: ProofType.photo,
        gufiDay: '2026-10-16',
        dueAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final committed = store.commitCommitment(draft.id);

      final proof = store.submitProof(
        commitmentId: committed.id,
        submitterId: 'user-alice',
        proofType: ProofType.photo,
        mediaUrl: 'https://storage.gufi.app/proofs/run.jpg',
      );

      store.reviewProof(
        proofId: proof.id,
        reviewerId: 'user-verifier',
        decision: ReviewDecision.rejected,
        reason: 'GPS track missing',
      );

      // Advance time by 7 hours (past the 6-hour correction deadline)
      final sevenHoursLater = DateTime.now().add(const Duration(hours: 7));

      // Server evaluates missed commitments
      final count = store.evaluateMissedCommitments(
        nowOverride: sevenHoursLater,
      );
      expect(count, 1);

      final comm = store.getCommitment(committed.id)!;
      expect(comm.status, CommitmentStatus.missed);
      expect(comm.resolvedAt, isNotNull);
    });

    test('Unsubmitted commitment with passed deadline is marked MISSED', () {
      final store = GufiBackendStore.instance;
      final pastDeadline = DateTime.utc(2026, 10, 16, 10, 0, 0);

      final draft = store.createDraftCommitment(
        ownerId: 'user-bob',
        title: 'Unfinished task',
        proofType: ProofType.text,
        gufiDay: '2026-10-16',
        dueAt: pastDeadline,
      );
      final committed = store.commitCommitment(draft.id);

      // Now is after deadline, no proof submitted
      final nowAfter = DateTime.utc(2026, 10, 16, 12, 0, 0);
      final count = store.evaluateMissedCommitments(nowOverride: nowAfter);
      expect(count, 1);

      final comm = store.getCommitment(committed.id)!;
      expect(comm.status, CommitmentStatus.missed);
    });
  });
}
