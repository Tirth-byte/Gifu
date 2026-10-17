enum CircleMemberRole {
  owner,
  member;

  static CircleMemberRole fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'owner':
        return CircleMemberRole.owner;
      case 'member':
        return CircleMemberRole.member;
      default:
        throw ArgumentError('Unknown CircleMemberRole: $value');
    }
  }

  String toDbString() => name;
}

enum CircleMemberStatus {
  active,
  left,
  removed;

  static CircleMemberStatus fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'active':
        return CircleMemberStatus.active;
      case 'left':
        return CircleMemberStatus.left;
      case 'removed':
        return CircleMemberStatus.removed;
      default:
        throw ArgumentError('Unknown CircleMemberStatus: $value');
    }
  }

  String toDbString() => name;
}

class CircleMember {
  final String id;
  final String circleId;
  final String userId;
  final CircleMemberRole role;
  final CircleMemberStatus status;
  final DateTime joinedAt;
  final DateTime updatedAt;

  const CircleMember({
    required this.id,
    required this.circleId,
    required this.userId,
    this.role = CircleMemberRole.member,
    this.status = CircleMemberStatus.active,
    required this.joinedAt,
    required this.updatedAt,
  });

  CircleMember copyWith({
    String? id,
    String? circleId,
    String? userId,
    CircleMemberRole? role,
    CircleMemberStatus? status,
    DateTime? joinedAt,
    DateTime? updatedAt,
  }) {
    return CircleMember(
      id: id ?? this.id,
      circleId: circleId ?? this.circleId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CircleMember.fromJson(Map<String, dynamic> json) {
    return CircleMember(
      id: json['id'] as String,
      circleId: json['circle_id'] as String,
      userId: json['user_id'] as String,
      role: CircleMemberRole.fromString((json['role'] as String?) ?? 'member'),
      status: CircleMemberStatus.fromString(
        (json['status'] as String?) ?? 'active',
      ),
      joinedAt: DateTime.parse(json['joined_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'circle_id': circleId,
      'user_id': userId,
      'role': role.toDbString(),
      'status': status.toDbString(),
      'joined_at': joinedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isActive => status == CircleMemberStatus.active;
  bool get isOwner => role == CircleMemberRole.owner;
}
