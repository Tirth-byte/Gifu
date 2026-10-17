import 'proof_type.dart';

enum ProofStatus {
  submitted,
  superseded;

  static ProofStatus fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'submitted':
        return ProofStatus.submitted;
      case 'superseded':
        return ProofStatus.superseded;
      default:
        throw ArgumentError('Unknown ProofStatus: $value');
    }
  }

  String toDbString() => name;
}

class Proof {
  final String id;
  final String commitmentId;
  final String submitterId;
  final ProofType proofType;
  final String? textContent;
  final String? mediaUrl;
  final DateTime submittedAt;
  final ProofStatus status;
  final DateTime createdAt;

  const Proof({
    required this.id,
    required this.commitmentId,
    required this.submitterId,
    required this.proofType,
    this.textContent,
    this.mediaUrl,
    required this.submittedAt,
    this.status = ProofStatus.submitted,
    required this.createdAt,
  });

  Proof copyWith({
    String? id,
    String? commitmentId,
    String? submitterId,
    ProofType? proofType,
    String? textContent,
    String? mediaUrl,
    DateTime? submittedAt,
    ProofStatus? status,
    DateTime? createdAt,
  }) {
    return Proof(
      id: id ?? this.id,
      commitmentId: commitmentId ?? this.commitmentId,
      submitterId: submitterId ?? this.submitterId,
      proofType: proofType ?? this.proofType,
      textContent: textContent ?? this.textContent,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      submittedAt: submittedAt ?? this.submittedAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Proof.fromJson(Map<String, dynamic> json) {
    return Proof(
      id: json['id'] as String,
      commitmentId: json['commitment_id'] as String,
      submitterId: json['submitter_id'] as String,
      proofType: ProofType.fromString(json['proof_type'] as String),
      textContent: json['text_content'] as String?,
      mediaUrl: json['media_url'] as String?,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      status: ProofStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'commitment_id': commitmentId,
      'submitter_id': submitterId,
      'proof_type': proofType.toDbString(),
      'text_content': textContent,
      'media_url': mediaUrl,
      'submitted_at': submittedAt.toIso8601String(),
      'status': status.toDbString(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
