import '../models/review.dart';

abstract class ReviewRepository {
  /// Submits a review decision ('approved' or 'rejected').
  /// - One approval transitions commitment to `verified`.
  /// - Rejection transitions commitment to `rejected`, initiating 6-hr correction window if on-time.
  /// - Owner cannot review own proof.
  /// - Reviewer must be an eligible circle member.
  /// - (proofId, reviewerId) is unique.
  Future<Review> reviewProof({
    required String proofId,
    required String reviewerId,
    required ReviewDecision decision,
    String? reason,
  });

  Future<List<Review>> getReviewsForProof(String proofId);

  Future<List<Review>> getReviewsForCommitment(String commitmentId);
}
