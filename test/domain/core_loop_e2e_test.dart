import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/core/services/gufi_backend_store.dart';
import 'package:gufi/features/auth/domain/models/user_profile.dart';
import 'package:gufi/features/commitments/domain/models/commitment_event.dart';
import 'package:gufi/features/commitments/domain/models/commitment_status.dart';
import 'package:gufi/features/commitments/domain/models/daily_result.dart';
import 'package:gufi/features/commitments/domain/models/proof.dart';
import 'package:gufi/features/commitments/domain/models/proof_type.dart';
import 'package:gufi/features/commitments/domain/models/review.dart';

void main() {
  setUp(() {
    GufiBackendStore.instance.reset();
  });

  group('Gufi Core Loop End-to-End Domain Pipeline', () {
    test('USER → CIRCLE → DRAFT → COMMIT → PROOF → REVIEW → VERIFIED → DAILY RESULT → MOMENTUM', () {
      final store = GufiBackendStore.instance;
      final now = DateTime.now();

      // 1. Users exist (using canonical UserProfile)
      final alice = UserProfile(
        id: 'user-alice-uid',
        email: 'alice@example.com',
        emailNormalized: 'alice@example.com',
        emailVerified: true,
        username: 'alice',
        usernameNormalized: 'alice',
        displayName: 'Alice M',
        role: 'user',
        onboardingCompleted: true,
        accountStatus: 'active',
        createdAt: now,
        updatedAt: now,
      );
      final bob = UserProfile(
        id: 'user-bob-uid',
        email: 'bob@example.com',
        emailNormalized: 'bob@example.com',
        emailVerified: true,
        username: 'bob',
        usernameNormalized: 'bob',
        displayName: 'Bob K',
        role: 'user',
        onboardingCompleted: true,
        accountStatus: 'active',
        createdAt: now,
        updatedAt: now,
      );
      store.saveUser(alice);
      store.saveUser(bob);

      // 2. Circle creation: Alice creates circle "Founders 6AM", Bob joins
      final circle = store.createCircle(
        name: 'Founders 6AM',
        ownerId: alice.id,
      );
      expect(circle.name, 'Founders 6AM');
      expect(
        store.isUserCircleMember(circleId: circle.id, userId: alice.id),
        isTrue,
      );

      store.addCircleMember(circleId: circle.id, userId: bob.id);
      expect(
        store.isUserCircleMember(circleId: circle.id, userId: bob.id),
        isTrue,
      );

      // 3. Alice creates a Draft commitment
      const currentDay = '2026-10-16';
      final draft = store.createDraftCommitment(
        ownerId: alice.id,
        circleId: circle.id,
        title: 'Ship landing page code',
        description: 'Complete hero section and deployment',
        proofType: ProofType.photo,
        gufiDay: currentDay,
        dueAt: now.add(const Duration(hours: 4)),
      );
      expect(draft.status, CommitmentStatus.draft);

      // Verify draft does NOT yet affect daily results or momentum
      final initialDaily = store.getDailyResult(
        userId: alice.id,
        gufiDay: currentDay,
      );
      expect(initialDaily.commitmentsTotal, 0);

      // 4. Alice COMMITS
      final committed = store.commitCommitment(draft.id);
      expect(committed.status, CommitmentStatus.committed);

      // Daily result is now inProgress
      final dailyAfterCommit = store.getDailyResult(
        userId: alice.id,
        gufiDay: currentDay,
      );
      expect(dailyAfterCommit.commitmentsTotal, 1);
      expect(dailyAfterCommit.dailyStatus, DailyStatus.inProgress);

      // 5. Alice submits photo proof
      final proof = store.submitProof(
        commitmentId: committed.id,
        submitterId: alice.id,
        proofType: ProofType.photo,
        mediaUrl: 'https://storage.gufi.app/proofs/alice/landing_deployed.jpg',
      );
      expect(proof.status, ProofStatus.submitted);

      final commAfterProof = store.getCommitment(committed.id)!;
      expect(commAfterProof.status, CommitmentStatus.proofSubmitted);

      // Daily result is now pendingReview
      final dailyAfterProof = store.getDailyResult(
        userId: alice.id,
        gufiDay: currentDay,
      );
      expect(dailyAfterProof.dailyStatus, DailyStatus.pendingReview);

      // 6. Bob reviews and APPROVES (1 approval verifies immediately)
      final review = store.reviewProof(
        proofId: proof.id,
        reviewerId: bob.id,
        decision: ReviewDecision.approved,
      );
      expect(review.isApproved, isTrue);

      final verifiedComm = store.getCommitment(committed.id)!;
      expect(verifiedComm.status, CommitmentStatus.verified);
      expect(verifiedComm.resolvedAt, isNotNull);

      // 7. Daily result updates to complete
      final finalDaily = store.getDailyResult(
        userId: alice.id,
        gufiDay: currentDay,
      );
      expect(finalDaily.commitmentsTotal, 1);
      expect(finalDaily.verifiedCount, 1);
      expect(finalDaily.completionPercentage, 100.0);
      expect(finalDaily.dailyStatus, DailyStatus.complete);

      // 8. Momentum reflects verified commitment (100%)
      final momentum = store.getMomentum(
        userId: alice.id,
        currentGufiDay: currentDay,
      );
      expect(momentum.isAvailable, isTrue);
      expect(momentum.verifiedCount, 1);
      expect(momentum.resolvedCount, 1);
      expect(momentum.score, 100);

      // 9. Events audit log has recorded the full immutable chain
      final events = store.getEventsForCommitment(draft.id);
      expect(events.length, 4);
      final eventTypes = events.map((e) => e.eventType).toList();
      expect(eventTypes, contains(CommitmentEventType.commitmentCreated));
      expect(eventTypes, contains(CommitmentEventType.commitmentCommitted));
      expect(eventTypes, contains(CommitmentEventType.proofSubmitted));
      expect(eventTypes, contains(CommitmentEventType.proofVerified));
    });
  });
}
