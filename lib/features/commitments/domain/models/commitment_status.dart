/// Explicit state machine states for a Gufi Commitment.
///
/// Gufi is NOT a generic task manager with arbitrary booleans.
/// State transitions follow a strict, deterministic sequence:
///
/// DRAFT → COMMITTED → PROOF_SUBMITTED → VERIFIED (Terminal)
///                   ↘ REJECTED → PROOF_SUBMITTED (Resubmission)
///                   ↘ MISSED (Terminal)
///                   ↘ CANCELLED (Terminal)
enum CommitmentStatus {
  draft,
  committed,
  proofSubmitted,
  rejected,
  verified,
  completed,
  missed,
  cancelled;

  static CommitmentStatus fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'draft':
        return CommitmentStatus.draft;
      case 'committed':
        return CommitmentStatus.committed;
      case 'proof_submitted':
      case 'proofsubmitted':
        return CommitmentStatus.proofSubmitted;
      case 'rejected':
        return CommitmentStatus.rejected;
      case 'verified':
        return CommitmentStatus.verified;
      case 'completed':
        return CommitmentStatus.completed;
      case 'missed':
        return CommitmentStatus.missed;
      case 'cancelled':
      case 'canceled':
        return CommitmentStatus.cancelled;
      default:
        throw ArgumentError('Unknown CommitmentStatus: $value');
    }
  }

  String toDbString() {
    switch (this) {
      case CommitmentStatus.proofSubmitted:
        return 'proof_submitted';
      default:
        return name;
    }
  }

  bool get isTerminal =>
      this == CommitmentStatus.verified ||
      this == CommitmentStatus.completed ||
      this == CommitmentStatus.missed ||
      this == CommitmentStatus.cancelled;

  bool get isResolved => isTerminal;

  bool get isPending =>
      this == CommitmentStatus.committed ||
      this == CommitmentStatus.proofSubmitted ||
      this == CommitmentStatus.rejected;

  /// Validates whether transitioning from `this` state to [target] is permitted.
  bool canTransitionTo(CommitmentStatus target) {
    if (this == target) return true;
    if (isTerminal) return false; // Terminal states cannot be changed

    switch (this) {
      case CommitmentStatus.draft:
        return target == CommitmentStatus.committed;

      case CommitmentStatus.committed:
        return target == CommitmentStatus.proofSubmitted ||
            target == CommitmentStatus.completed ||
            target == CommitmentStatus.cancelled ||
            target == CommitmentStatus.missed;

      case CommitmentStatus.proofSubmitted:
        return target == CommitmentStatus.verified ||
            target == CommitmentStatus.rejected ||
            target == CommitmentStatus.cancelled;

      case CommitmentStatus.rejected:
        return target == CommitmentStatus.proofSubmitted ||
            target == CommitmentStatus.missed ||
            target == CommitmentStatus.cancelled;

      case CommitmentStatus.verified:
      case CommitmentStatus.completed:
      case CommitmentStatus.missed:
      case CommitmentStatus.cancelled:
        return false;
    }
  }
}
