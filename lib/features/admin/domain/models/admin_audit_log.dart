/// Audit log event recorded when an administrator takes a sensitive action.
class AdminAuditLog {
  final String id;
  final String adminUserId;
  final String? adminEmail;
  final String action;
  final String? targetUserId;
  final String? targetEmail;
  final String? details;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const AdminAuditLog({
    required this.id,
    this.adminUserId = 'admin-uid',
    this.adminEmail,
    required this.action,
    this.targetUserId,
    this.targetEmail,
    this.details,
    this.metadata,
    required this.createdAt,
  });

  String get humanAction {
    switch (action) {
      case 'USER_DISABLED':
      case 'ADMIN_DISABLED_USER':
        return 'Disabled user';
      case 'USER_ENABLED':
      case 'ADMIN_ENABLED_USER':
        return 'Enabled user';
      case 'USERS_EXPORTED':
      case 'ADMIN_EXPORTED_USERS':
        return 'Exported users';
      default:
        return action;
    }
  }

  factory AdminAuditLog.fromJson(Map<String, dynamic> json) {
    return AdminAuditLog(
      id: json['id'] as String? ?? '',
      adminUserId: json['admin_user_id'] as String? ?? 'admin-uid',
      adminEmail: json['admin_email'] as String? ?? 'admin@gufi.app',
      action: json['action'] as String? ?? '',
      targetUserId: json['target_user_id'] as String?,
      targetEmail: json['target_email'] as String?,
      details: json['details'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'admin_user_id': adminUserId,
      'admin_email': adminEmail,
      'action': action,
      'target_user_id': targetUserId,
      'target_email': targetEmail,
      'details': details,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
