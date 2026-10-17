import '../models/accountability_scope.dart';
import '../models/commitment.dart';
import '../models/proof_type.dart';

abstract class CommitmentRepository {
  Future<Commitment> createDraft({
    required String ownerId,
    String? circleId,
    AccountabilityScope? accountabilityScope,
    required String title,
    String? description,
    ProofType? proofType,
    required String gufiDay,
    required DateTime dueAt,
    String timezone = 'UTC',
  });

  Future<Commitment> updateDraft({
    required String commitmentId,
    required String ownerId,
    String? circleId,
    AccountabilityScope? accountabilityScope,
    String? title,
    String? description,
    ProofType? proofType,
    DateTime? dueAt,
  });

  Future<void> deleteDraft({
    required String commitmentId,
    required String ownerId,
  });

  /// Transitions draft to committed status.
  /// Server-side & transactional check: ensures max 3 commitments per Gufi day.
  Future<Commitment> commit(String commitmentId);

  /// Transitions committed/proof_submitted/rejected to cancelled.
  /// Counts as NOT KEPT for Momentum.
  Future<Commitment> cancelCommitment({
    required String commitmentId,
    required String ownerId,
    String? reason,
  });

  Future<Commitment?> getCommitment(String commitmentId);

  Future<List<Commitment>> getUserCommitmentsForDay({
    required String userId,
    required String gufiDay,
  });

  Future<List<Commitment>> getCircleCommitmentsForDay({
    required String circleId,
    required String gufiDay,
  });

  /// Server sweep to mark expired commitments without on-time proofs as MISSED.
  Future<int> evaluateMissedCommitments();
}
