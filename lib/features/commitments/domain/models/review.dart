enum ReviewDecision {
  approved,
  rejected;

  static ReviewDecision fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'approved':
        return ReviewDecision.approved;
      case 'rejected':
        return ReviewDecision.rejected;
      default:
        throw ArgumentError('Unknown ReviewDecision: $value');
    }
  }

  String toDbString() => name;
}

class Review {
  final String id;
  final String proofId;
  final String commitmentId;
  final String reviewerId;
  final ReviewDecision decision;
  final String? reason;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.proofId,
    required this.commitmentId,
    required this.reviewerId,
    required this.decision,
    this.reason,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      proofId: json['proof_id'] as String,
      commitmentId: json['commitment_id'] as String,
      reviewerId: json['reviewer_id'] as String,
      decision: ReviewDecision.fromString(json['decision'] as String),
      reason: json['reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'proof_id': proofId,
      'commitment_id': commitmentId,
      'reviewer_id': reviewerId,
      'decision': decision.toDbString(),
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isApproved => decision == ReviewDecision.approved;
  bool get isRejected => decision == ReviewDecision.rejected;
}
