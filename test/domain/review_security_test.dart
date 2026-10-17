import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/core/services/gufi_backend_store.dart';
import 'package:gufi/features/commitments/domain/models/commitment_status.dart';
import 'package:gufi/features/commitments/domain/models/proof_type.dart';
import 'package:gufi/features/commitments/domain/models/review.dart';

void main() {
  setUp(() {
    GufiBackendStore.instance.reset();
  });

  group('Review Security & Permission Rules', () {
    test('Commitment owner CANNOT review their own proof', () {
      final store = GufiBackendStore.instance;
      final circle = store.createCircle(
        name: 'Solo/Partner',
        ownerId: 'user-alice',
      );

      final draft = store.createDraftCommitment(
        ownerId: 'user-alice',
        circleId: circle.id,
        title: 'Morning Yoga',
        proofType: ProofType.photo,
        gufiDay: '2026-10-16',
        dueAt: DateTime.now().add(const Duration(hours: 4)),
      );
      final committed = store.commitCommitment(draft.id);

      final proof = store.submitProof(
        commitmentId: committed.id,
        submitterId: 'user-alice',
        proofType: ProofType.photo,
        mediaUrl: 'https://storage.gufi.app/proofs/alice/yoga.jpg',
      );

      // Alice tries to approve her own proof -> DENIED
      expect(
        () => store.reviewProof(
          proofId: proof.id,
          reviewerId: 'user-alice',
          decision: ReviewDecision.approved,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('cannot review their own proof'),
          ),
        ),
      );
    });

    test('Non-circle member CANNOT review circle proof', () {
      final store = GufiBackendStore.instance;
      final circle = store.createCircle(
        name: 'Coding Circle',
        ownerId: 'user-alice',
      );
      // Eve is NOT added to circle

      final draft = store.createDraftCommitment(
        ownerId: 'user-alice',
        circleId: circle.id,
        title: 'Leetcode 2 problems',
        proofType: ProofType.text,
        gufiDay: '2026-10-16',
        dueAt: DateTime.now().add(const Duration(hours: 4)),
      );
      final committed = store.commitCommitment(draft.id);
      final proof = store.submitProof(
        commitmentId: committed.id,
        submitterId: 'user-alice',
        proofType: ProofType.text,
        textContent: 'Solved two pointers problem',
      );

      // Eve attempts to review
      expect(
        () => store.reviewProof(
          proofId: proof.id,
          reviewerId: 'user-eve',
          decision: ReviewDecision.approved,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('only active circle members can review'),
          ),
        ),
      );
    });

    test('Active circle member CAN review proof and 1 approval verifies immediately', () {
      final store = GufiBackendStore.instance;
      final circle = store.createCircle(
        name: 'Gym Bros',
        ownerId: 'user-alice',
      );
      store.addCircleMember(circleId: circle.id, userId: 'user-bob');
      store.addCircleMember(circleId: circle.id, userId: 'user-charlie');

      final draft = store.createDraftCommitment(
        ownerId: 'user-alice',
        circleId: circle.id,
        title: 'Bench press 80kg',
        proofType: ProofType.photo,
        gufiDay: '2026-10-16',
        dueAt: DateTime.now().add(const Duration(hours: 4)),
      );
      final committed = store.commitCommitment(draft.id);
      final proof = store.submitProof(
        commitmentId: committed.id,
        submitterId: 'user-alice',
        proofType: ProofType.photo,
        mediaUrl: 'https://storage.gufi.app/proofs/alice/gym.jpg',
      );

      // Bob approves
      final review = store.reviewProof(
        proofId: proof.id,
        reviewerId: 'user-bob',
        decision: ReviewDecision.approved,
      );

      expect(review.isApproved, isTrue);
      final updated = store.getCommitment(committed.id)!;
      // VERIFIED immediately (no majority or consensus needed)
      expect(updated.status, CommitmentStatus.verified);
      expect(updated.resolvedAt, isNotNull);
    });

    test('Duplicate review by the same reviewer is denied', () {
      final store = GufiBackendStore.instance;
      final circle = store.createCircle(
        name: 'Read Daily',
        ownerId: 'user-alice',
      );
      store.addCircleMember(circleId: circle.id, userId: 'user-bob');

      final draft = store.createDraftCommitment(
        ownerId: 'user-alice',
        circleId: circle.id,
        title: 'Read chapter 1',
        proofType: ProofType.text,
        gufiDay: '2026-10-16',
        dueAt: DateTime.now().add(const Duration(hours: 4)),
      );
      final committed = store.commitCommitment(draft.id);
      final proof = store.submitProof(
        commitmentId: committed.id,
        submitterId: 'user-alice',
        proofType: ProofType.text,
        textContent: 'Notes on chapter 1',
      );

      // First review succeeds
      store.reviewProof(
        proofId: proof.id,
        reviewerId: 'user-bob',
        decision: ReviewDecision.approved,
      );

      // Second review by same reviewer fails
      expect(
        () => store.reviewProof(
          proofId: proof.id,
          reviewerId: 'user-bob',
          decision: ReviewDecision.approved,
        ),
        throwsStateError,
      );
    });

    test('Rejection without reason is denied', () {
      final store = GufiBackendStore.instance;
      final circle = store.createCircle(name: 'Writing', ownerId: 'user-alice');
      store.addCircleMember(circleId: circle.id, userId: 'user-bob');

      final draft = store.createDraftCommitment(
        ownerId: 'user-alice',
        circleId: circle.id,
        title: 'Write 500 words',
        proofType: ProofType.text,
        gufiDay: '2026-10-16',
        dueAt: DateTime.now().add(const Duration(hours: 4)),
      );
      final committed = store.commitCommitment(draft.id);
      final proof = store.submitProof(
        commitmentId: committed.id,
        submitterId: 'user-alice',
        proofType: ProofType.text,
        textContent: 'My article draft',
      );

      // Rejection with empty reason
      expect(
        () => store.reviewProof(
          proofId: proof.id,
          reviewerId: 'user-bob',
          decision: ReviewDecision.rejected,
          reason: '',
        ),
        throwsArgumentError,
      );

      // Rejection with null reason
      expect(
        () => store.reviewProof(
          proofId: proof.id,
          reviewerId: 'user-bob',
          decision: ReviewDecision.rejected,
          reason: null,
        ),
        throwsArgumentError,
      );
    });

    test(
      'Approval reason is completely OPTIONAL (can be null or provided)',
      () {
        final store = GufiBackendStore.instance;
        final circle = store.createCircle(
          name: 'Reading Club',
          ownerId: 'user-alice',
        );
        store.addCircleMember(circleId: circle.id, userId: 'user-bob');
        store.addCircleMember(circleId: circle.id, userId: 'user-charlie');

        // Commitment 1: Alice submits proof, Bob approves without any reason (null)
        final draft1 = store.createDraftCommitment(
          ownerId: 'user-alice',
          circleId: circle.id,
          title: 'Task 1',
          proofType: ProofType.text,
          gufiDay: '2026-10-16',
          dueAt: DateTime.now().add(const Duration(hours: 4)),
        );
        final comm1 = store.commitCommitment(draft1.id);
        final proof1 = store.submitProof(
          commitmentId: comm1.id,
          submitterId: 'user-alice',
          proofType: ProofType.text,
          textContent: 'Done 1',
        );

        final review1 = store.reviewProof(
          proofId: proof1.id,
          reviewerId: 'user-bob',
          decision: ReviewDecision.approved,
          reason: null, // OPTIONAL
        );
        expect(review1.isApproved, isTrue);
        expect(review1.reason, isNull);
        expect(
          store.getCommitment(comm1.id)!.status,
          CommitmentStatus.verified,
        );

        // Commitment 2: Charlie approves WITH optional note
        final draft2 = store.createDraftCommitment(
          ownerId: 'user-alice',
          circleId: circle.id,
          title: 'Task 2',
          proofType: ProofType.text,
          gufiDay: '2026-10-16',
          dueAt: DateTime.now().add(const Duration(hours: 4)),
        );
        final comm2 = store.commitCommitment(draft2.id);
        final proof2 = store.submitProof(
          commitmentId: comm2.id,
          submitterId: 'user-alice',
          proofType: ProofType.text,
          textContent: 'Done 2',
        );

        final review2 = store.reviewProof(
          proofId: proof2.id,
          reviewerId: 'user-charlie',
          decision: ReviewDecision.approved,
          reason: 'Great job!', // Provided optional note
        );
        expect(review2.isApproved, isTrue);
        expect(review2.reason, 'Great job!');
        expect(
          store.getCommitment(comm2.id)!.status,
          CommitmentStatus.verified,
        );
      },
    );
  });
}
