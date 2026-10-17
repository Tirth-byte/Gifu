/// Canonical event types for the immutable commitment audit stream.
enum CommitmentEventType {
  commitmentCreated,
  commitmentCommitted,
  commitmentCancelled,
  commitmentMissed,
  proofSubmitted,
  proofRejected,
  proofResubmitted,
  proofVerified,
  circleCreated,
  memberJoined;

  static CommitmentEventType fromString(String value) {
    switch (value.trim().toUpperCase()) {
      case 'COMMITMENT_CREATED':
        return CommitmentEventType.commitmentCreated;
      case 'COMMITMENT_COMMITTED':
        return CommitmentEventType.commitmentCommitted;
      case 'COMMITMENT_CANCELLED':
        return CommitmentEventType.commitmentCancelled;
      case 'COMMITMENT_MISSED':
        return CommitmentEventType.commitmentMissed;
      case 'PROOF_SUBMITTED':
        return CommitmentEventType.proofSubmitted;
      case 'PROOF_REJECTED':
        return CommitmentEventType.proofRejected;
      case 'PROOF_RESUBMITTED':
        return CommitmentEventType.proofResubmitted;
      case 'PROOF_VERIFIED':
        return CommitmentEventType.proofVerified;
      case 'CIRCLE_CREATED':
        return CommitmentEventType.circleCreated;
      case 'MEMBER_JOINED':
        return CommitmentEventType.memberJoined;
      default:
        throw ArgumentError('Unknown CommitmentEventType: $value');
    }
  }

  String toDbString() {
    switch (this) {
      case CommitmentEventType.commitmentCreated:
        return 'COMMITMENT_CREATED';
      case CommitmentEventType.commitmentCommitted:
        return 'COMMITMENT_COMMITTED';
      case CommitmentEventType.commitmentCancelled:
        return 'COMMITMENT_CANCELLED';
      case CommitmentEventType.commitmentMissed:
        return 'COMMITMENT_MISSED';
      case CommitmentEventType.proofSubmitted:
        return 'PROOF_SUBMITTED';
      case CommitmentEventType.proofRejected:
        return 'PROOF_REJECTED';
      case CommitmentEventType.proofResubmitted:
        return 'PROOF_RESUBMITTED';
      case CommitmentEventType.proofVerified:
        return 'PROOF_VERIFIED';
      case CommitmentEventType.circleCreated:
        return 'CIRCLE_CREATED';
      case CommitmentEventType.memberJoined:
        return 'MEMBER_JOINED';
    }
  }
}

/// Immutable event record in Gufi domain.
class CommitmentEvent {
  final String id;
  final String commitmentId;
  final String? actorId;
  final CommitmentEventType eventType;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const CommitmentEvent({
    required this.id,
    required this.commitmentId,
    this.actorId,
    required this.eventType,
    this.metadata,
    required this.createdAt,
  });

  factory CommitmentEvent.fromJson(Map<String, dynamic> json) {
    return CommitmentEvent(
      id: json['id'] as String,
      commitmentId: json['commitment_id'] as String,
      actorId: json['actor_id'] as String?,
      eventType: CommitmentEventType.fromString(json['event_type'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'commitment_id': commitmentId,
      'actor_id': actorId,
      'event_type': eventType.toDbString(),
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
