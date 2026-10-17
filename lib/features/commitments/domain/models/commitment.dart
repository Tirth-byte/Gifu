import 'accountability_scope.dart';
import 'commitment_status.dart';
import 'proof_type.dart';

/// Strongly typed Gufi Commitment domain entity.
/// Represents a sacred promise made by a user.
class Commitment {
  final String id;
  final String ownerId;
  final String? circleId;
  final AccountabilityScope accountabilityScope;
  final String title;
  final String? description;
  final ProofType? proofType;
  final String gufiDay; // 'YYYY-MM-DD'
  final DateTime dueAt;
  final String timezone;
  final CommitmentStatus status;
  final DateTime? committedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final DateTime? resolvedAt;
  final DateTime? correctionDeadline;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Commitment({
    required this.id,
    required this.ownerId,
    this.circleId,
    this.accountabilityScope = AccountabilityScope.circle,
    required this.title,
    this.description,
    this.proofType,
    required this.gufiDay,
    required this.dueAt,
    this.timezone = 'UTC',
    required this.status,
    this.committedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.resolvedAt,
    this.correctionDeadline,
    required this.createdAt,
    required this.updatedAt,
  });

  Commitment copyWith({
    String? id,
    String? ownerId,
    String? circleId,
    AccountabilityScope? accountabilityScope,
    String? title,
    String? description,
    ProofType? proofType,
    String? gufiDay,
    DateTime? dueAt,
    String? timezone,
    CommitmentStatus? status,
    DateTime? committedAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    DateTime? resolvedAt,
    DateTime? correctionDeadline,
    bool clearCorrectionDeadline = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Commitment(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      circleId: circleId ?? this.circleId,
      accountabilityScope: accountabilityScope ?? this.accountabilityScope,
      title: title ?? this.title,
      description: description ?? this.description,
      proofType: proofType ?? this.proofType,
      gufiDay: gufiDay ?? this.gufiDay,
      dueAt: dueAt ?? this.dueAt,
      timezone: timezone ?? this.timezone,
      status: status ?? this.status,
      committedAt: committedAt ?? this.committedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      correctionDeadline: clearCorrectionDeadline
          ? null
          : (correctionDeadline ?? this.correctionDeadline),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Commitment.fromJson(Map<String, dynamic> json) {
    final circleId = json['circle_id'] as String?;
    final scopeStr = json['accountability_scope'] as String?;
    final scope = scopeStr != null
        ? AccountabilityScope.fromString(scopeStr)
        : (circleId != null
              ? AccountabilityScope.circle
              : AccountabilityScope.private);

    return Commitment(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      circleId: circleId,
      accountabilityScope: scope,
      title: json['title'] as String,
      description: json['description'] as String?,
      proofType: json['proof_type'] != null
          ? ProofType.fromString(json['proof_type'] as String)
          : null,
      gufiDay: json['gufi_day'] as String,
      dueAt: DateTime.parse(json['due_at'] as String),
      timezone: (json['timezone'] as String?) ?? 'UTC',
      status: CommitmentStatus.fromString(json['status'] as String),
      committedAt: json['committed_at'] != null
          ? DateTime.parse(json['committed_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      cancellationReason: json['cancellation_reason'] as String?,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      correctionDeadline: json['correction_deadline'] != null
          ? DateTime.parse(json['correction_deadline'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'circle_id': circleId,
      'accountability_scope': accountabilityScope.toDbString(),
      'title': title,
      'description': description,
      'proof_type': proofType?.toDbString(),
      'gufi_day': gufiDay,
      'due_at': dueAt.toIso8601String(),
      'timezone': timezone,
      'status': status.toDbString(),
      'committed_at': committedAt?.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'cancellation_reason': cancellationReason,
      'resolved_at': resolvedAt?.toIso8601String(),
      'correction_deadline': correctionDeadline?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isDraft => status == CommitmentStatus.draft;
  bool get isCommitted => status == CommitmentStatus.committed;
  bool get isProofSubmitted => status == CommitmentStatus.proofSubmitted;
  bool get isVerified => status == CommitmentStatus.verified;
  bool get isCompleted => status == CommitmentStatus.completed;
  bool get isRejected => status == CommitmentStatus.rejected;
  bool get isMissed => status == CommitmentStatus.missed;
  bool get isCancelled => status == CommitmentStatus.cancelled;

  bool get isPrivate => accountabilityScope == AccountabilityScope.private;
  bool get isCircle => accountabilityScope == AccountabilityScope.circle;
}
