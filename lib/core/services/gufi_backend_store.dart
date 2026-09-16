import 'dart:async';

import '../../features/admin/domain/models/admin_audit_log.dart';
import '../../features/admin/domain/models/admin_user_summary.dart';
import '../../features/auth/domain/models/user_profile.dart';

/// Single source of truth in-memory backend store for local/preview/testing execution.
/// Ensures that Auth, Coming Soon, Admin Overview, Database Grid, and Audit Logs
/// all query and update the exact same data.
///
/// Starts completely clean (0 users, 0 fake data) per the Zero-Mock principle.
class GufiBackendStore {
  static final GufiBackendStore instance = GufiBackendStore._internal();
  GufiBackendStore._internal();

  final Map<String, UserProfile> _usersById = {};
  final Map<String, String> _passwordsByEmail = {};
  final List<AdminAuditLog> _auditLogs = [];

  final StreamController<void> _changeNotifier =
      StreamController<void>.broadcast();
  Stream<void> get onDataChanged => _changeNotifier.stream;

  /// Clear all store data (useful for tests or complete reset)
  void reset() {
    _usersById.clear();
    _passwordsByEmail.clear();
    _auditLogs.clear();
    _changeNotifier.add(null);
  }

  // ==========================================
  // USER OPERATIONS
  // ==========================================

  List<UserProfile> getAllUsers() => _usersById.values.toList();

  int get userCount => _usersById.length;

  UserProfile? getUserById(String id) => _usersById[id];

  UserProfile? getUserByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    for (final user in _usersById.values) {
      if (user.emailNormalized == normalized) return user;
    }
    return null;
  }

  UserProfile? getUserByUsername(String username) {
    final normalized = username.trim().toLowerCase().replaceFirst('@', '');
    for (final user in _usersById.values) {
      if (user.usernameNormalized == normalized) return user;
    }
    return null;
  }

  bool emailExists(String email) => getUserByEmail(email) != null;

  bool usernameExists(String username) => getUserByUsername(username) != null;

  void saveUser(UserProfile profile, {String? password}) {
    _usersById[profile.id] = profile;
    if (password != null && password.isNotEmpty) {
      _passwordsByEmail[profile.emailNormalized] = password;
    }
    _changeNotifier.add(null);
  }

  bool verifyPassword(String email, String password) {
    final normalized = email.trim().toLowerCase();
    final stored = _passwordsByEmail[normalized];
    return stored != null && stored == password;
  }

  void updateUserStatus(
    String userId,
    String status, {
    String adminEmail = 'admin@gufi.app',
    bool recordAuditLog = true,
  }) {
    final user = _usersById[userId];
    if (user != null) {
      final updated = user.copyWith(
        accountStatus: status,
        updatedAt: DateTime.now(),
      );
      _usersById[userId] = updated;

      // Log audit event if requested
      if (recordAuditLog) {
        final action = status == 'disabled' ? 'USER_DISABLED' : 'USER_ENABLED';
        addAuditLog(
          action: action,
          adminEmail: adminEmail,
          targetUserId: userId,
          targetEmail: user.email,
          details: 'Admin changed user status to $status',
        );
      }

      _changeNotifier.add(null);
    }
  }

  List<AdminUserSummary> getAdminSummaries() {
    return _usersById.values.map((u) {
      return AdminUserSummary(
        id: u.id,
        email: u.email,
        emailNormalized: u.emailNormalized,
        emailVerified: u.emailVerified,
        username: u.username,
        usernameNormalized: u.usernameNormalized,
        displayName: u.displayName ?? u.username,
        profilePhotoUrl: u.profilePhotoUrl,
        authProvider: u.authProvider,
        role: u.role,
        onboardingCompleted: u.onboardingCompleted,
        accountStatus: u.accountStatus,
        createdAt: u.createdAt,
        updatedAt: u.updatedAt,
      );
    }).toList();
  }

  // ==========================================
  // AUDIT LOG OPERATIONS
  // ==========================================

  List<AdminAuditLog> getAuditLogs() => List.unmodifiable(_auditLogs.reversed);

  void addAuditLog({
    required String action,
    required String adminEmail,
    String? targetUserId,
    String? targetEmail,
    String? details,
  }) {
    final log = AdminAuditLog(
      id: 'audit-${DateTime.now().millisecondsSinceEpoch}-${_auditLogs.length + 1}',
      action: action,
      adminEmail: adminEmail,
      targetUserId: targetUserId,
      targetEmail: targetEmail,
      details: details,
      createdAt: DateTime.now(),
    );
    _auditLogs.add(log);
    _changeNotifier.add(null);
  }
}
