import 'dart:async';
import 'dart:math';

import '../../features/admin/domain/models/admin_audit_log.dart';
import '../../features/admin/domain/models/admin_user_summary.dart';
import '../../features/auth/domain/models/user_profile.dart';
import '../../features/circles/domain/models/circle.dart';
import '../../features/circles/domain/models/circle_invite.dart';
import '../../features/circles/domain/models/circle_member.dart';
import '../../features/commitments/domain/models/accountability_scope.dart';
import '../../features/commitments/domain/models/commitment.dart';
import '../../features/commitments/domain/models/commitment_event.dart';
import '../../features/commitments/domain/models/commitment_status.dart';
import '../../features/commitments/domain/models/daily_result.dart';
import '../../features/commitments/domain/models/momentum_result.dart';
import '../../features/commitments/domain/models/proof.dart';
import '../../features/commitments/domain/models/proof_type.dart';
import '../../features/commitments/domain/models/review.dart';

/// Single source of truth backend store for local/preview/testing execution.
/// Ensures that Auth, Admin, Circles, Commitments, Proofs, Reviews, Events, Daily Results,
/// and Momentum all query and update the exact same domain data with 100% backend parity.
///
/// In-memory store for testing and preview parity. Production relies solely on Supabase.
class GufiBackendStore {
  static final GufiBackendStore instance = GufiBackendStore._internal();
  GufiBackendStore._internal();

  // Users & Auth
  String? _currentSessionUserId;
  final Map<String, UserProfile> _usersById = {};
  final Map<String, String> _passwordsByEmail = {};
  final List<AdminAuditLog> _auditLogs = [];

  // Circles & Memberships
  final Map<String, Circle> _circlesById = {};
  final List<CircleMember> _circleMembers = [];
  final Map<String, CircleInvite> _invitesByCode = {};

  // Commitments, Proofs, Reviews, Events, Daily Results
  final Map<String, Commitment> _commitmentsById = {};
  final Map<String, Proof> _proofsById = {};
  final List<Review> _reviews = [];
  final List<CommitmentEvent> _events = [];
  final Map<String, DailyResult> _dailyResults = {}; // key: '$userId:$gufiDay'

  final StreamController<void> _changeNotifier =
      StreamController<void>.broadcast();
  Stream<void> get onDataChanged => _changeNotifier.stream;

  String? get currentSessionUserId => _currentSessionUserId;
  UserProfile? get currentSessionUser =>
      _currentSessionUserId != null ? _usersById[_currentSessionUserId] : null;

  void setCurrentSessionUser(String? userId) {
    _currentSessionUserId = userId;
    _changeNotifier.add(null);
  }

  /// Initialize store (in-memory setup)
  Future<void> init() async {}

  /// Clear all store data (useful for tests or complete reset)
  void reset({bool clearDisk = false}) {
    _currentSessionUserId = null;
    _usersById.clear();
    _passwordsByEmail.clear();
    _auditLogs.clear();
    _circlesById.clear();
    _circleMembers.clear();
    _invitesByCode.clear();
    _commitmentsById.clear();
    _proofsById.clear();
    _reviews.clear();
    _events.clear();
    _dailyResults.clear();
    _circlesByRequestId.clear();
    _changeNotifier.add(null);
  }

  /// Sign out current session
  void signOut() {
    _currentSessionUserId = null;
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

  // ==========================================
  // CIRCLES & MEMBERS OPERATIONS
  // ==========================================

  final Map<String, Circle> _circlesByRequestId = {};

  Circle createCircle({
    required String name,
    required String ownerId,
    String? description,
    String? inviteCode,
    String? requestId,
  }) {
    if (requestId != null && requestId.trim().isNotEmpty) {
      final existing = _circlesByRequestId['$ownerId:${requestId.trim()}'];
      if (existing != null) return existing;
    }
    if (name.trim().isEmpty) throw ArgumentError('Circle name is required');
    final now = DateTime.now();
    final circleId =
        'circle-${now.millisecondsSinceEpoch}-${_circlesById.length + 1}';

    final circle = Circle(
      id: circleId,
      name: name.trim(),
      ownerId: ownerId,
      description: description != null && description.trim().isNotEmpty
          ? description.trim()
          : null,
      status: CircleStatus.active,
      createdAt: now,
      updatedAt: now,
    );
    _circlesById[circleId] = circle;

    // Owner automatically becomes a member
    final member = CircleMember(
      id: 'cm-${now.millisecondsSinceEpoch}-owner',
      circleId: circleId,
      userId: ownerId,
      role: CircleMemberRole.owner,
      status: CircleMemberStatus.active,
      joinedAt: now,
      updatedAt: now,
    );
    _circleMembers.add(member);

    // Automatically create primary invite for this circle
    createCircleInvite(
      circleId: circleId,
      creatorId: ownerId,
      customCode: inviteCode,
    );

    _events.add(
      CommitmentEvent(
        id: 'event-${now.millisecondsSinceEpoch}',
        commitmentId: circleId,
        actorId: ownerId,
        eventType: CommitmentEventType.circleCreated,
        metadata: {'circle_name': circle.name},
        createdAt: now,
      ),
    );

    if (requestId != null && requestId.trim().isNotEmpty) {
      _circlesByRequestId['$ownerId:${requestId.trim()}'] = circle;
    }

    _changeNotifier.add(null);
    return circle;
  }

  Circle? getCircle(String circleId) => _circlesById[circleId];

  List<Circle> getUserCircles(String userId) {
    final activeCircleIds = _circleMembers
        .where(
          (m) => m.userId == userId && m.status == CircleMemberStatus.active,
        )
        .map((m) => m.circleId)
        .toSet();

    return _circlesById.values
        .where(
          (c) =>
              activeCircleIds.contains(c.id) && c.status == CircleStatus.active,
        )
        .toList();
  }

  CircleMember addCircleMember({
    required String circleId,
    required String userId,
    CircleMemberRole role = CircleMemberRole.member,
  }) {
    final existingIdx = _circleMembers.indexWhere(
      (m) => m.circleId == circleId && m.userId == userId,
    );
    final now = DateTime.now();

    if (existingIdx != -1) {
      final existing = _circleMembers[existingIdx];
      if (existing.status == CircleMemberStatus.active) {
        return existing; // already member
      }
      final reactivated = existing.copyWith(
        status: CircleMemberStatus.active,
        role: role,
        updatedAt: now,
      );
      _circleMembers[existingIdx] = reactivated;
      _changeNotifier.add(null);
      return reactivated;
    }

    final newMember = CircleMember(
      id: 'cm-${now.millisecondsSinceEpoch}-${_circleMembers.length + 1}',
      circleId: circleId,
      userId: userId,
      role: role,
      status: CircleMemberStatus.active,
      joinedAt: now,
      updatedAt: now,
    );
    _circleMembers.add(newMember);

    _events.add(
      CommitmentEvent(
        id: 'event-${now.millisecondsSinceEpoch}',
        commitmentId: circleId,
        actorId: userId,
        eventType: CommitmentEventType.memberJoined,
        metadata: {'circle_id': circleId, 'role': role.toDbString()},
        createdAt: now,
      ),
    );

    _changeNotifier.add(null);
    return newMember;
  }

  void removeCircleMember({required String circleId, required String userId}) {
    final idx = _circleMembers.indexWhere(
      (m) => m.circleId == circleId && m.userId == userId,
    );
    if (idx != -1) {
      _circleMembers[idx] = _circleMembers[idx].copyWith(
        status: CircleMemberStatus.removed,
        updatedAt: DateTime.now(),
      );
      _changeNotifier.add(null);
    }
  }

  List<CircleMember> getCircleMembers(String circleId) {
    return _circleMembers
        .where(
          (m) =>
              m.circleId == circleId && m.status == CircleMemberStatus.active,
        )
        .toList();
  }

  bool isUserCircleMember({required String circleId, required String userId}) {
    final circle = _circlesById[circleId];
    if (circle != null && circle.ownerId == userId) return true;
    return _circleMembers.any(
      (m) =>
          m.circleId == circleId &&
          m.userId == userId &&
          m.status == CircleMemberStatus.active,
    );
  }

  // ==========================================
  // CIRCLE INVITES OPERATIONS
  // ==========================================

  static String normalizeInviteCode(String input) {
    var raw = input.trim();
    if (raw.isEmpty) return '';

    // Handle URI / query parameters
    if (raw.toLowerCase().contains('code=')) {
      final idx = raw.toLowerCase().indexOf('code=');
      raw = raw.substring(idx + 5);
      final amp = raw.indexOf('&');
      if (amp != -1) raw = raw.substring(0, amp);
    } else if (raw.toLowerCase().contains('/join/')) {
      final parts = raw.split(RegExp(r'/join/', caseSensitive: false));
      if (parts.length > 1) {
        raw = parts.last.split('?').first.split('#').first;
      }
    }

    if (raw.toLowerCase().startsWith('gufi://')) {
      raw = raw.substring(7);
    }

    raw = raw.trim().toUpperCase();
    if (raw.startsWith('GUFI-')) {
      raw = raw.substring(5);
    } else if (raw.startsWith('GUFI ')) {
      raw = raw.substring(5);
    } else if (raw.startsWith('GUFI') && raw.length > 4) {
      raw = raw.substring(4);
    }

    // Clean suffix to allowed alphabet characters
    raw = raw.replaceAll(RegExp(r'[^23456789ABCDEFGHJKLMNPQRSTUVWXYZ]'), '');
    if (raw.isEmpty) return '';

    return 'GUFI-$raw';
  }

  String generateInviteCode() {
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final rand = Random();
    String code;
    do {
      final suffix = List.generate(
        6,
        (_) => chars[rand.nextInt(chars.length)],
      ).join();
      code = 'GUFI-$suffix';
    } while (_invitesByCode.containsKey(code));
    return code;
  }

  CircleInvite createCircleInvite({
    required String circleId,
    required String creatorId,
    String? customCode,
    DateTime? expiresAt,
    int? maxUses,
  }) {
    final circle = _circlesById[circleId];
    if (circle == null) throw ArgumentError('Circle not found: $circleId');

    final code = customCode != null && customCode.trim().isNotEmpty
        ? normalizeInviteCode(customCode)
        : generateInviteCode();

    final now = DateTime.now();
    final invite = CircleInvite(
      id: 'cinv-${now.millisecondsSinceEpoch}-${_invitesByCode.length + 1}',
      circleId: circleId,
      code: code,
      creatorId: creatorId,
      status: CircleInviteStatus.active,
      expiresAt: expiresAt,
      maxUses: maxUses,
      useCount: 0,
      createdAt: now,
      updatedAt: now,
    );

    _invitesByCode[code] = invite;
    _changeNotifier.add(null);
    return invite;
  }

  CircleInvite? getInviteByCode(String code) {
    final normalized = normalizeInviteCode(code);
    return _invitesByCode[normalized];
  }

  CircleInvite? getActiveInviteForCircle(String circleId) {
    for (final invite in _invitesByCode.values) {
      if (invite.circleId == circleId && invite.isActive) {
        return invite;
      }
    }
    return null;
  }

  void updateInviteStatus(String code, CircleInviteStatus status) {
    final normalized = normalizeInviteCode(code);
    final invite = _invitesByCode[normalized];
    if (invite != null) {
      _invitesByCode[normalized] = invite.copyWith(
        status: status,
        updatedAt: DateTime.now(),
      );
      _changeNotifier.add(null);
    }
  }

  InviteResolutionResult resolveInviteCode({
    required String code,
    required String? currentUserId,
  }) {
    final normalized = normalizeInviteCode(code);
    if (normalized.isEmpty) {
      return const InviteResolvedInvalid();
    }

    final invite = _invitesByCode[normalized];
    if (invite == null) {
      return const InviteResolvedInvalid();
    }

    if (invite.status == CircleInviteStatus.revoked) {
      return const InviteResolvedRevoked();
    }

    if (invite.isExpired) {
      return const InviteResolvedExpired();
    }

    final circle = _circlesById[invite.circleId];
    if (circle == null || circle.status != CircleStatus.active) {
      return const InviteResolvedInvalid();
    }

    // Get active members safely
    final activeMembers = getCircleMembers(circle.id);
    final previewMembers = <CirclePreviewMember>[];
    for (final member in activeMembers) {
      final user = _usersById[member.userId];
      final displayName = user?.displayName ?? user?.username ?? 'Member';
      previewMembers.add(
        CirclePreviewMember(
          id: member.userId,
          displayName: displayName,
          profilePhotoUrl: user?.profilePhotoUrl,
        ),
      );
    }

    final creator = _usersById[circle.ownerId];
    final creatorName = creator?.displayName ?? creator?.username;

    final inviter = _usersById[invite.creatorId];
    final inviterName = inviter?.displayName ?? inviter?.username;

    final preview = CirclePreview(
      circleId: circle.id,
      circleName: circle.name,
      description: circle.description,
      inviteCode: invite.code,
      creatorName: creatorName,
      inviterName: inviterName,
      memberCount: activeMembers.length,
      previewMembers: previewMembers.take(4).toList(),
    );

    if (currentUserId != null &&
        isUserCircleMember(circleId: circle.id, userId: currentUserId)) {
      return InviteResolvedAlreadyMember(preview);
    }

    return InviteResolvedValid(preview);
  }

  JoinCircleResult joinCircleWithInvite({
    required String code,
    required String userId,
  }) {
    final normalized = normalizeInviteCode(code);
    final invite = _invitesByCode[normalized];
    if (invite == null) {
      return const JoinCircleFailure('We couldn’t find that invite.');
    }

    if (invite.status == CircleInviteStatus.revoked) {
      return const JoinCircleFailure('This invite is no longer active.');
    }

    if (invite.isExpired) {
      return const JoinCircleFailure('This invite has expired.');
    }

    final circle = _circlesById[invite.circleId];
    if (circle == null || circle.status != CircleStatus.active) {
      return const JoinCircleFailure('Circle is no longer active.');
    }

    if (isUserCircleMember(circleId: circle.id, userId: userId)) {
      return JoinCircleAlreadyMember(circleId: circle.id);
    }

    // Add member
    addCircleMember(
      circleId: circle.id,
      userId: userId,
      role: CircleMemberRole.member,
    );

    // Increment invite usage
    _invitesByCode[normalized] = invite.copyWith(
      useCount: invite.useCount + 1,
      updatedAt: DateTime.now(),
    );

    _changeNotifier.add(null);
    return JoinCircleSuccess(circleId: circle.id);
  }

  // ==========================================
  // COMMITMENTS OPERATIONS
  // ==========================================

  Commitment createDraftCommitment({
    required String ownerId,
    String? circleId,
    AccountabilityScope? accountabilityScope,
    required String title,
    String? description,
    ProofType? proofType,
    required String gufiDay,
    required DateTime dueAt,
    String timezone = 'UTC',
  }) {
    if (title.trim().isEmpty) throw ArgumentError('Title is required');

    final scope = accountabilityScope ?? AccountabilityScope.circle;

    if (scope == AccountabilityScope.private && circleId != null) {
      throw ArgumentError('Private commitments cannot have a circleId');
    }

    final now = DateTime.now();
    final id =
        'comm-${now.millisecondsSinceEpoch}-${_commitmentsById.length + 1}';

    final commitment = Commitment(
      id: id,
      ownerId: ownerId,
      circleId: scope == AccountabilityScope.circle ? circleId : null,
      accountabilityScope: scope,
      title: title.trim(),
      description: description?.trim(),
      proofType: proofType,
      gufiDay: gufiDay,
      dueAt: dueAt,
      timezone: timezone,
      status: CommitmentStatus.draft,
      createdAt: now,
      updatedAt: now,
    );

    _commitmentsById[id] = commitment;
    _events.add(
      CommitmentEvent(
        id: 'event-${now.millisecondsSinceEpoch}',
        commitmentId: id,
        actorId: ownerId,
        eventType: CommitmentEventType.commitmentCreated,
        metadata: {
          'title': commitment.title,
          'gufi_day': gufiDay,
          'accountability_scope': scope.name,
        },
        createdAt: now,
      ),
    );

    _changeNotifier.add(null);
    return commitment;
  }

  Commitment updateDraftCommitment({
    required String commitmentId,
    required String ownerId,
    String? circleId,
    AccountabilityScope? accountabilityScope,
    String? title,
    String? description,
    ProofType? proofType,
    DateTime? dueAt,
  }) {
    final existing = _commitmentsById[commitmentId];
    if (existing == null) throw StateError('Commitment not found');
    if (existing.ownerId != ownerId) throw StateError('Unauthorized');
    if (existing.status != CommitmentStatus.draft) {
      throw StateError('Only draft commitments can be modified');
    }

    final newScope = accountabilityScope ?? existing.accountabilityScope;
    final updated = existing.copyWith(
      circleId: newScope == AccountabilityScope.circle
          ? (circleId ?? existing.circleId)
          : null,
      accountabilityScope: newScope,
      title: title?.trim() ?? existing.title,
      description: description?.trim() ?? existing.description,
      proofType: proofType ?? existing.proofType,
      dueAt: dueAt ?? existing.dueAt,
      updatedAt: DateTime.now(),
    );

    _commitmentsById[commitmentId] = updated;
    _changeNotifier.add(null);
    return updated;
  }

  void deleteDraftCommitment({
    required String commitmentId,
    required String ownerId,
  }) {
    final existing = _commitmentsById[commitmentId];
    if (existing == null) return;
    if (existing.ownerId != ownerId) throw StateError('Unauthorized');
    if (existing.status != CommitmentStatus.draft) {
      throw StateError('Committed promises cannot be deleted');
    }

    _commitmentsById.remove(commitmentId);
    _changeNotifier.add(null);
  }

  /// Atomic commit operation: enforces maximum 3 commitments per Gufi day.
  Commitment commitCommitment(String commitmentId) {
    final existing = _commitmentsById[commitmentId];
    if (existing == null) throw StateError('Commitment not found');
    if (existing.status != CommitmentStatus.draft) {
      throw StateError('Only draft commitments can be committed');
    }

    // Atomic server-side limit check
    final activeCount = _commitmentsById.values
        .where(
          (c) =>
              c.ownerId == existing.ownerId &&
              c.gufiDay == existing.gufiDay &&
              c.status != CommitmentStatus.draft,
        )
        .length;

    if (activeCount >= 3) {
      throw StateError(
        'Daily limit reached: maximum 3 commitments per Gufi day',
      );
    }

    final now = DateTime.now();
    final committed = existing.copyWith(
      status: CommitmentStatus.committed,
      committedAt: now,
      updatedAt: now,
    );

    _commitmentsById[commitmentId] = committed;
    _events.add(
      CommitmentEvent(
        id: 'event-${now.millisecondsSinceEpoch}',
        commitmentId: commitmentId,
        actorId: existing.ownerId,
        eventType: CommitmentEventType.commitmentCommitted,
        metadata: {'gufi_day': existing.gufiDay},
        createdAt: now,
      ),
    );

    recalculateDailyResult(existing.ownerId, existing.gufiDay);
    _changeNotifier.add(null);
    return committed;
  }

  Commitment cancelCommitment({
    required String commitmentId,
    required String ownerId,
    String? reason,
  }) {
    final existing = _commitmentsById[commitmentId];
    if (existing == null) throw StateError('Commitment not found');
    if (existing.ownerId != ownerId) throw StateError('Unauthorized');
    if (!existing.status.canTransitionTo(CommitmentStatus.cancelled)) {
      throw StateError(
        'Illegal transition to cancelled from ${existing.status}',
      );
    }

    final now = DateTime.now();
    final cancelled = existing.copyWith(
      status: CommitmentStatus.cancelled,
      cancelledAt: now,
      cancellationReason: reason,
      resolvedAt: now,
      updatedAt: now,
    );

    _commitmentsById[commitmentId] = cancelled;
    _events.add(
      CommitmentEvent(
        id: 'event-${now.millisecondsSinceEpoch}',
        commitmentId: commitmentId,
        actorId: ownerId,
        eventType: CommitmentEventType.commitmentCancelled,
        metadata: {'reason': reason},
        createdAt: now,
      ),
    );

    recalculateDailyResult(existing.ownerId, existing.gufiDay);
    _changeNotifier.add(null);
    return cancelled;
  }

  Commitment? getCommitment(String commitmentId) =>
      _commitmentsById[commitmentId];

  List<Commitment> getUserCommitmentsForDay({
    required String userId,
    required String gufiDay,
  }) {
    return _commitmentsById.values
        .where((c) => c.ownerId == userId && c.gufiDay == gufiDay)
        .toList();
  }

  List<Commitment> getCircleCommitmentsForDay({
    required String circleId,
    required String gufiDay,
  }) {
    return _commitmentsById.values
        .where(
          (c) =>
              c.circleId == circleId &&
              c.gufiDay == gufiDay &&
              c.status != CommitmentStatus.draft,
        )
        .toList();
  }

  List<Commitment> getAllCommitments() => _commitmentsById.values.toList();

  // ==========================================
  // PROOFS OPERATIONS
  // ==========================================

  Proof submitProof({
    required String commitmentId,
    required String submitterId,
    required ProofType proofType,
    String? textContent,
    String? mediaUrl,
    DateTime? nowOverride,
  }) {
    final commitment = _commitmentsById[commitmentId];
    if (commitment == null) throw StateError('Commitment not found');
    if (commitment.ownerId != submitterId) throw StateError('Unauthorized');
    if (commitment.status != CommitmentStatus.committed &&
        commitment.status != CommitmentStatus.rejected) {
      throw StateError(
        'Proof cannot be submitted in status ${commitment.status}',
      );
    }

    final now = nowOverride ?? DateTime.now();
    // If rejected, check correction deadline
    if (commitment.status == CommitmentStatus.rejected &&
        commitment.correctionDeadline != null &&
        now.isAfter(commitment.correctionDeadline!)) {
      throw StateError('Correction window has expired for this commitment');
    }

    if (proofType == ProofType.text &&
        (textContent == null || textContent.trim().isEmpty)) {
      throw ArgumentError('Text content is required for text proof');
    }
    if (proofType == ProofType.photo &&
        (mediaUrl == null || mediaUrl.trim().isEmpty)) {
      throw ArgumentError('Media URL is required for photo proof');
    }

    // Supersede any existing submitted proofs for this commitment
    for (final key in _proofsById.keys) {
      final p = _proofsById[key]!;
      if (p.commitmentId == commitmentId && p.status == ProofStatus.submitted) {
        _proofsById[key] = p.copyWith(status: ProofStatus.superseded);
      }
    }

    final proofId =
        'proof-${now.millisecondsSinceEpoch}-${_proofsById.length + 1}';
    final proof = Proof(
      id: proofId,
      commitmentId: commitmentId,
      submitterId: submitterId,
      proofType: proofType,
      textContent: textContent?.trim(),
      mediaUrl: mediaUrl?.trim(),
      submittedAt: now,
      status: ProofStatus.submitted,
      createdAt: now,
    );
    _proofsById[proofId] = proof;

    final isPrivate =
        commitment.accountabilityScope == AccountabilityScope.private;
    final targetStatus = isPrivate
        ? CommitmentStatus.completed
        : CommitmentStatus.proofSubmitted;

    _commitmentsById[commitmentId] = commitment.copyWith(
      status: targetStatus,
      proofType: proofType,
      resolvedAt: isPrivate ? now : null,
      clearCorrectionDeadline: true,
      updatedAt: now,
    );

    final eventType = isPrivate
        ? CommitmentEventType.commitmentCreated
        : (commitment.status == CommitmentStatus.rejected
              ? CommitmentEventType.proofResubmitted
              : CommitmentEventType.proofSubmitted);

    _events.add(
      CommitmentEvent(
        id: 'event-${now.millisecondsSinceEpoch}',
        commitmentId: commitmentId,
        actorId: submitterId,
        eventType: eventType,
        metadata: {'proof_id': proofId, 'target_status': targetStatus.name},
        createdAt: now,
      ),
    );

    recalculateDailyResult(commitment.ownerId, commitment.gufiDay);
    _changeNotifier.add(null);
    return proof;
  }

  Proof? getProof(String proofId) => _proofsById[proofId];

  List<Proof> getProofsForCommitment(String commitmentId) {
    return _proofsById.values
        .where((p) => p.commitmentId == commitmentId)
        .toList();
  }

  // ==========================================
  // REVIEWS OPERATIONS
  // ==========================================

  Review reviewProof({
    required String proofId,
    required String reviewerId,
    required ReviewDecision decision,
    String? reason,
    DateTime? nowOverride,
  }) {
    final proof = _proofsById[proofId];
    if (proof == null) throw StateError('Proof not found');

    final commitment = _commitmentsById[proof.commitmentId];
    if (commitment == null) throw StateError('Commitment not found');

    // Rule 1: Owner CANNOT review own proof
    if (commitment.ownerId == reviewerId) {
      throw StateError('Commitment owner cannot review their own proof');
    }

    // Rule 2: Reviewer must be an eligible circle member (if circle commitment)
    if (commitment.circleId != null &&
        !isUserCircleMember(
          circleId: commitment.circleId!,
          userId: reviewerId,
        )) {
      throw StateError('Unauthorized: only active circle members can review');
    }

    // Rule 3: Must be in proofSubmitted state
    if (commitment.status != CommitmentStatus.proofSubmitted) {
      throw StateError('Commitment is not awaiting review');
    }

    // Rule 4: Rejection requires reason
    if (decision == ReviewDecision.rejected &&
        (reason == null || reason.trim().isEmpty)) {
      throw ArgumentError('Rejection requires a short reason');
    }

    // Rule 5: Unique (proof_id, reviewer_id)
    final existingReview = _reviews.any(
      (r) => r.proofId == proofId && r.reviewerId == reviewerId,
    );
    if (existingReview) {
      throw StateError('Reviewer has already reviewed this proof');
    }

    final now = nowOverride ?? DateTime.now();
    final reviewId = 'rev-${now.millisecondsSinceEpoch}-${_reviews.length + 1}';
    final review = Review(
      id: reviewId,
      proofId: proofId,
      commitmentId: commitment.id,
      reviewerId: reviewerId,
      decision: decision,
      reason: reason?.trim(),
      createdAt: now,
    );
    _reviews.add(review);

    if (decision == ReviewDecision.approved) {
      // ONE approval is enough -> VERIFIED
      _commitmentsById[commitment.id] = commitment.copyWith(
        status: CommitmentStatus.verified,
        resolvedAt: now,
        clearCorrectionDeadline: true,
        updatedAt: now,
      );

      _events.add(
        CommitmentEvent(
          id: 'event-${now.millisecondsSinceEpoch}',
          commitmentId: commitment.id,
          actorId: reviewerId,
          eventType: CommitmentEventType.proofVerified,
          metadata: {'review_id': reviewId},
          createdAt: now,
        ),
      );
    } else {
      // REJECTED
      // If proof was submitted ON TIME before dueAt, grant 6-hour correction window
      DateTime? corrDeadline;
      if (!proof.submittedAt.isAfter(commitment.dueAt)) {
        corrDeadline = now.add(const Duration(hours: 6));
      }

      _commitmentsById[commitment.id] = commitment.copyWith(
        status: CommitmentStatus.rejected,
        correctionDeadline: corrDeadline,
        updatedAt: now,
      );

      _events.add(
        CommitmentEvent(
          id: 'event-${now.millisecondsSinceEpoch}',
          commitmentId: commitment.id,
          actorId: reviewerId,
          eventType: CommitmentEventType.proofRejected,
          metadata: {
            'review_id': reviewId,
            'reason': reason,
            'correction_deadline': corrDeadline?.toIso8601String(),
          },
          createdAt: now,
        ),
      );
    }

    recalculateDailyResult(commitment.ownerId, commitment.gufiDay);
    _changeNotifier.add(null);
    return review;
  }

  List<Review> getReviewsForProof(String proofId) {
    return _reviews.where((r) => r.proofId == proofId).toList();
  }

  List<Review> getReviewsForCommitment(String commitmentId) {
    return _reviews.where((r) => r.commitmentId == commitmentId).toList();
  }

  List<CommitmentEvent> getEventsForCommitment(String commitmentId) {
    return _events.where((e) => e.commitmentId == commitmentId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ==========================================
  // SERVER SWEEP: EVALUATE MISSED COMMITMENTS
  // ==========================================

  int evaluateMissedCommitments({DateTime? nowOverride}) {
    final now = nowOverride ?? DateTime.now();
    int missedCount = 0;

    for (final commitment in _commitmentsById.values.toList()) {
      // 1. Committed state where dueAt has passed and no proof was submitted
      if (commitment.status == CommitmentStatus.committed &&
          now.isAfter(commitment.dueAt)) {
        _commitmentsById[commitment.id] = commitment.copyWith(
          status: CommitmentStatus.missed,
          resolvedAt: now,
          updatedAt: now,
        );

        _events.add(
          CommitmentEvent(
            id: 'event-${now.millisecondsSinceEpoch}-$missedCount',
            commitmentId: commitment.id,
            actorId: null, // System event
            eventType: CommitmentEventType.commitmentMissed,
            metadata: {'reason': 'deadline_passed_without_proof'},
            createdAt: now,
          ),
        );

        recalculateDailyResult(commitment.ownerId, commitment.gufiDay);
        missedCount++;
      }
      // 2. Rejected state where correction deadline has passed without resubmission
      else if (commitment.status == CommitmentStatus.rejected &&
          commitment.correctionDeadline != null &&
          now.isAfter(commitment.correctionDeadline!)) {
        _commitmentsById[commitment.id] = commitment.copyWith(
          status: CommitmentStatus.missed,
          resolvedAt: now,
          updatedAt: now,
        );

        _events.add(
          CommitmentEvent(
            id: 'event-${now.millisecondsSinceEpoch}-$missedCount',
            commitmentId: commitment.id,
            actorId: null,
            eventType: CommitmentEventType.commitmentMissed,
            metadata: {'reason': 'correction_window_expired'},
            createdAt: now,
          ),
        );

        recalculateDailyResult(commitment.ownerId, commitment.gufiDay);
        missedCount++;
      }

      // NOTE: If status == proof_submitted, it is NEVER marked missed here
      // because user met timing requirement and is awaiting review!
    }

    if (missedCount > 0) {
      _changeNotifier.add(null);
    }
    return missedCount;
  }

  // ==========================================
  // DAILY RESULTS & MOMENTUM
  // ==========================================

  DailyResult recalculateDailyResult(String userId, String gufiDay) {
    final commitments = _commitmentsById.values
        .where(
          (c) =>
              c.ownerId == userId &&
              c.gufiDay == gufiDay &&
              c.status != CommitmentStatus.draft,
        )
        .toList();

    final total = commitments.length;
    final verified = commitments
        .where((c) => c.status == CommitmentStatus.verified)
        .length;
    final completed = commitments
        .where((c) => c.status == CommitmentStatus.completed)
        .length;
    final missed = commitments
        .where((c) => c.status == CommitmentStatus.missed)
        .length;
    final cancelled = commitments
        .where((c) => c.status == CommitmentStatus.cancelled)
        .length;
    final pending = commitments.where((c) => c.status.isPending).length;

    DailyStatus status;
    double pct = 0.0;

    if (total > 0) {
      final kept = verified + completed;
      pct = double.parse(((kept / total) * 100.0).toStringAsFixed(2));
      if (pending > 0) {
        if (commitments.any(
          (c) => c.status == CommitmentStatus.proofSubmitted,
        )) {
          status = DailyStatus.pendingReview;
        } else {
          status = DailyStatus.inProgress;
        }
      } else if (kept == total) {
        status = DailyStatus.complete;
      } else if (kept > 0) {
        status = DailyStatus.partial;
      } else {
        status = DailyStatus.missed;
      }
    } else {
      status = DailyStatus.empty;
      pct = 0.0;
    }

    final result = DailyResult(
      userId: userId,
      gufiDay: gufiDay,
      commitmentsTotal: total,
      verifiedCount: verified,
      missedCount: missed,
      cancelledCount: cancelled,
      pendingCount: pending,
      completionPercentage: pct,
      dailyStatus: status,
      updatedAt: DateTime.now(),
    );

    _dailyResults['$userId:$gufiDay'] = result;
    return result;
  }

  DailyResult getDailyResult({
    required String userId,
    required String gufiDay,
  }) {
    return _dailyResults['$userId:$gufiDay'] ??
        recalculateDailyResult(userId, gufiDay);
  }

  /// Calculates 7-day Momentum: VERIFIED / (VERIFIED + MISSED + CANCELLED) * 100
  /// Window: [currentGufiDay - 6 days, currentGufiDay]
  /// IMPORTANT: Only socially verified circle commitments contribute to Momentum!
  /// Private promises do NOT contribute to Momentum so users cannot self-verify.
  MomentumResult getMomentum({
    required String userId,
    required String currentGufiDay,
  }) {
    final currDate = DateTime.parse(currentGufiDay);
    final startDate = currDate.subtract(const Duration(days: 6));

    final inWindow = _commitmentsById.values.where((c) {
      if (c.ownerId != userId) return false;
      // Private promises do NOT affect Momentum
      if (c.accountabilityScope == AccountabilityScope.private) return false;
      try {
        final cDate = DateTime.parse(c.gufiDay);
        if (cDate.isBefore(startDate) || cDate.isAfter(currDate)) return false;
      } catch (_) {
        return false;
      }
      return c.status.isResolved;
    }).toList();

    final verified = inWindow
        .where((c) => c.status == CommitmentStatus.verified)
        .length;
    final missed = inWindow
        .where((c) => c.status == CommitmentStatus.missed)
        .length;
    final cancelled = inWindow
        .where((c) => c.status == CommitmentStatus.cancelled)
        .length;

    return MomentumResult.fromCounts(
      verified: verified,
      missed: missed,
      cancelled: cancelled,
    );
  }
}
