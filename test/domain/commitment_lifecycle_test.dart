import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/core/services/gufi_backend_store.dart';
import 'package:gufi/features/commitments/domain/models/commitment_status.dart';
import 'package:gufi/features/commitments/domain/models/proof_type.dart';
import 'package:gufi/features/commitments/domain/models/review.dart';

void main() {
  setUp(() {
    GufiBackendStore.instance.reset();
  });

  group('Commitment State Machine & Lifecycle Transitions', () {
    test('State machine strictly defines valid transitions', () {
      // Draft can only transition to committed
      expect(
        CommitmentStatus.draft.canTransitionTo(CommitmentStatus.committed),
        isTrue,
      );
      expect(
        CommitmentStatus.draft.canTransitionTo(CommitmentStatus.verified),
        isFalse,
      );
      expect(
        CommitmentStatus.draft.canTransitionTo(CommitmentStatus.missed),
        isFalse,
      );

      // Committed can transition to proof_submitted, cancelled, missed
      expect(
        CommitmentStatus.committed.canTransitionTo(
          CommitmentStatus.proofSubmitted,
        ),
        isTrue,
      );
      expect(
        CommitmentStatus.committed.canTransitionTo(CommitmentStatus.cancelled),
        isTrue,
      );
      expect(
        CommitmentStatus.committed.canTransitionTo(CommitmentStatus.missed),
        isTrue,
      );
      expect(
        CommitmentStatus.committed.canTransitionTo(CommitmentStatus.verified),
        isFalse,
      );

      // Proof submitted can transition to verified, rejected, cancelled
      expect(
        CommitmentStatus.proofSubmitted.canTransitionTo(
          CommitmentStatus.verified,
        ),
        isTrue,
      );
      expect(
        CommitmentStatus.proofSubmitted.canTransitionTo(
          CommitmentStatus.rejected,
        ),
        isTrue,
      );
      expect(
        CommitmentStatus.proofSubmitted.canTransitionTo(
          CommitmentStatus.cancelled,
        ),
        isTrue,
      );
      expect(
        CommitmentStatus.proofSubmitted.canTransitionTo(CommitmentStatus.draft),
        isFalse,
      );

      // Rejected can transition to proofSubmitted (resubmit), missed, cancelled
      expect(
        CommitmentStatus.rejected.canTransitionTo(
          CommitmentStatus.proofSubmitted,
        ),
        isTrue,
      );
      expect(
        CommitmentStatus.rejected.canTransitionTo(CommitmentStatus.missed),
        isTrue,
      );
      expect(
        CommitmentStatus.rejected.canTransitionTo(CommitmentStatus.cancelled),
        isTrue,
      );

      // Terminal states cannot transition to anything
      expect(CommitmentStatus.verified.isTerminal, isTrue);
      expect(CommitmentStatus.missed.isTerminal, isTrue);
      expect(CommitmentStatus.cancelled.isTerminal, isTrue);

      expect(
        CommitmentStatus.verified.canTransitionTo(CommitmentStatus.draft),
        isFalse,
      );
      expect(
        CommitmentStatus.verified.canTransitionTo(CommitmentStatus.committed),
        isFalse,
      );
      expect(
        CommitmentStatus.missed.canTransitionTo(CommitmentStatus.committed),
        isFalse,
      );
      expect(
        CommitmentStatus.cancelled.canTransitionTo(CommitmentStatus.committed),
        isFalse,
      );
    });

    test('Full lifecycle: DRAFT → COMMITTED → PROOF_SUBMITTED → VERIFIED', () {
      final store = GufiBackendStore.instance;

      // 1. Create circle & members
      final circle = store.createCircle(
        name: 'Morning Routine',
        ownerId: 'user-alice',
      );
      store.addCircleMember(circleId: circle.id, userId: 'user-bob');

      // 2. Draft creation
      final draft = store.createDraftCommitment(
        ownerId: 'user-alice',
        circleId: circle.id,
        title: '30 min morning run',
        proofType: ProofType.photo,
        gufiDay: '2026-10-16',
        dueAt: DateTime.now().add(const Duration(hours: 4)),
      );
      expect(draft.status, CommitmentStatus.draft);

      // 3. Commit
      final committed = store.commitCommitment(draft.id);
      expect(committed.status, CommitmentStatus.committed);
      expect(committed.committedAt, isNotNull);

      // 4. Submit Proof
      final proof = store.submitProof(
        commitmentId: committed.id,
        submitterId: 'user-alice',
        proofType: ProofType.photo,
        mediaUrl: 'https://storage.gufi.app/proofs/user-alice/run.jpg',
      );
      expect(proof.proofType, ProofType.photo);

      final updatedComm = store.getCommitment(committed.id)!;
      expect(updatedComm.status, CommitmentStatus.proofSubmitted);

      // 5. Review by circle member Bob -> Verified
      final review = store.reviewProof(
        proofId: proof.id,
        reviewerId: 'user-bob',
        decision: ReviewDecision.approved,
      );
      expect(review.isApproved, isTrue);

      final verifiedComm = store.getCommitment(committed.id)!;
      expect(verifiedComm.status, CommitmentStatus.verified);
      expect(verifiedComm.resolvedAt, isNotNull);
    });

    test('Rejection and Resubmission cycle: PROOF_SUBMITTED → REJECTED → PROOF_SUBMITTED → VERIFIED', () {
      final store = GufiBackendStore.instance;
      final circle = store.createCircle(
        name: 'Study Circle',
        ownerId: 'user-alice',
      );
      store.addCircleMember(circleId: circle.id, userId: 'user-bob');

      final draft = store.createDraftCommitment(
        ownerId: 'user-alice',
        circleId: circle.id,
        title: 'Read 20 pages',
        proofType: ProofType.text,
        gufiDay: '2026-10-16',
        dueAt: DateTime.now().add(const Duration(hours: 2)),
      );
      final committed = store.commitCommitment(draft.id);

      // Submit first proof
      final proof1 = store.submitProof(
        commitmentId: committed.id,
        submitterId: 'user-alice',
        proofType: ProofType.text,
        textContent: 'Done',
      );

      // Bob rejects with reason
      final review1 = store.reviewProof(
        proofId: proof1.id,
        reviewerId: 'user-bob',
        decision: ReviewDecision.rejected,
        reason: 'Too short, need page summary',
      );
      expect(review1.isRejected, isTrue);

      final rejectedComm = store.getCommitment(committed.id)!;
      expect(rejectedComm.status, CommitmentStatus.rejected);
      expect(rejectedComm.correctionDeadline, isNotNull);

      // Alice resubmits within correction window
      final proof2 = store.submitProof(
        commitmentId: committed.id,
        submitterId: 'user-alice',
        proofType: ProofType.text,
        textContent: 'Pages 40-60 covered chapter 3 on atomic habits with summary notes.',
      );

      final resubmittedComm = store.getCommitment(committed.id)!;
      expect(resubmittedComm.status, CommitmentStatus.proofSubmitted);

      // Bob approves second proof
      store.reviewProof(
        proofId: proof2.id,
        reviewerId: 'user-bob',
        decision: ReviewDecision.approved,
      );

      final verifiedComm = store.getCommitment(committed.id)!;
      expect(verifiedComm.status, CommitmentStatus.verified);
    });

    test(
      'Cancellation transitions commitment to CANCELLED and records reason',
      () {
        final store = GufiBackendStore.instance;
        final draft = store.createDraftCommitment(
          ownerId: 'user-alice',
          title: 'Meditate 15m',
          proofType: ProofType.text,
          gufiDay: '2026-10-16',
          dueAt: DateTime.now().add(const Duration(hours: 3)),
        );
        final committed = store.commitCommitment(draft.id);

        final cancelled = store.cancelCommitment(
          commitmentId: committed.id,
          ownerId: 'user-alice',
          reason: 'Emergency travel',
        );

        expect(cancelled.status, CommitmentStatus.cancelled);
        expect(cancelled.cancellationReason, 'Emergency travel');
        expect(cancelled.cancelledAt, isNotNull);
        expect(cancelled.resolvedAt, isNotNull);
      },
    );

    test('Illegal direct jumps are blocked', () {
      final store = GufiBackendStore.instance;
      final draft = store.createDraftCommitment(
        ownerId: 'user-alice',
        title: 'Sleep early',
        proofType: ProofType.text,
        gufiDay: '2026-10-16',
        dueAt: DateTime.now().add(const Duration(hours: 1)),
      );

      // Cannot submit proof directly for a draft
      expect(
        () => store.submitProof(
          commitmentId: draft.id,
          submitterId: 'user-alice',
          proofType: ProofType.text,
          textContent: 'proof',
        ),
        throwsStateError,
      );

      // Cannot cancel a draft via commitment cancellation
      expect(
        () => store.cancelCommitment(
          commitmentId: draft.id,
          ownerId: 'user-alice',
        ),
        throwsStateError,
      );
    });
  });
}
