enum CircleInviteStatus {
  active,
  revoked,
  expired;

  static CircleInviteStatus fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'active':
        return CircleInviteStatus.active;
      case 'revoked':
        return CircleInviteStatus.revoked;
      case 'expired':
        return CircleInviteStatus.expired;
      default:
        return CircleInviteStatus.active;
    }
  }

  String toDbString() => name;
}

class CircleInvite {
  final String id;
  final String circleId;
  final String code;
  final String creatorId;
  final CircleInviteStatus status;
  final DateTime? expiresAt;
  final int? maxUses;
  final int useCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CircleInvite({
    required this.id,
    required this.circleId,
    required this.code,
    required this.creatorId,
    this.status = CircleInviteStatus.active,
    this.expiresAt,
    this.maxUses,
    this.useCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isExpired {
    if (status == CircleInviteStatus.expired) return true;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return true;
    if (maxUses != null && useCount >= maxUses!) return true;
    return false;
  }

  bool get isActive => status == CircleInviteStatus.active && !isExpired;

  CircleInvite copyWith({
    String? id,
    String? circleId,
    String? code,
    String? creatorId,
    CircleInviteStatus? status,
    DateTime? expiresAt,
    int? maxUses,
    int? useCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CircleInvite(
      id: id ?? this.id,
      circleId: circleId ?? this.circleId,
      code: code ?? this.code,
      creatorId: creatorId ?? this.creatorId,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      maxUses: maxUses ?? this.maxUses,
      useCount: useCount ?? this.useCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CircleInvite.fromJson(Map<String, dynamic> json) {
    return CircleInvite(
      id: json['id'] as String,
      circleId: json['circle_id'] as String,
      code: (json['code'] as String).trim().toUpperCase(),
      creatorId: json['creator_id'] as String,
      status: CircleInviteStatus.fromString(
        (json['status'] as String?) ?? 'active',
      ),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      maxUses: json['max_uses'] as int?,
      useCount: (json['use_count'] as int?) ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'circle_id': circleId,
      'code': code,
      'creator_id': creatorId,
      'status': status.toDbString(),
      if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
      if (maxUses != null) 'max_uses': maxUses,
      'use_count': useCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Safe preview of member identity to display before user joins
class CirclePreviewMember {
  final String id;
  final String displayName;
  final String? profilePhotoUrl;

  const CirclePreviewMember({
    required this.id,
    required this.displayName,
    this.profilePhotoUrl,
  });
}

/// Safe circle preview information exposed before joining.
/// Strictly excludes private commitments, proofs, reviews, or emails.
class CirclePreview {
  final String circleId;
  final String circleName;
  final String? description;
  final String inviteCode;
  final String? creatorName;
  final String? inviterName;
  final int memberCount;
  final List<CirclePreviewMember> previewMembers;

  const CirclePreview({
    required this.circleId,
    required this.circleName,
    this.description,
    required this.inviteCode,
    this.creatorName,
    this.inviterName,
    required this.memberCount,
    this.previewMembers = const [],
  });
}

/// Result of resolving an invite code against backend
sealed class InviteResolutionResult {
  const InviteResolutionResult();
}

class InviteResolvedValid extends InviteResolutionResult {
  final CirclePreview preview;
  const InviteResolvedValid(this.preview);
}

class InviteResolvedAlreadyMember extends InviteResolutionResult {
  final CirclePreview preview;
  const InviteResolvedAlreadyMember(this.preview);
}

class InviteResolvedInvalid extends InviteResolutionResult {
  final String message;
  const InviteResolvedInvalid({this.message = 'We couldn’t find that invite.'});
}

class InviteResolvedExpired extends InviteResolutionResult {
  final String message;
  final String supporting;
  const InviteResolvedExpired({
    this.message = 'This invite has expired.',
    this.supporting = 'Ask someone in the Circle for a new invite.',
  });
}

class InviteResolvedRevoked extends InviteResolutionResult {
  final String message;
  const InviteResolvedRevoked({
    this.message = 'This invite is no longer active.',
  });
}

/// Result of joining a circle with an invite code
sealed class JoinCircleResult {
  const JoinCircleResult();
}

class JoinCircleSuccess extends JoinCircleResult {
  final String circleId;
  const JoinCircleSuccess({required this.circleId});
}

class JoinCircleAlreadyMember extends JoinCircleResult {
  final String circleId;
  const JoinCircleAlreadyMember({required this.circleId});
}

class JoinCircleFailure extends JoinCircleResult {
  final String message;
  const JoinCircleFailure(this.message);
}
