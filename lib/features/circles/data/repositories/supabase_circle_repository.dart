import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/services/gufi_backend_store.dart';
import '../../domain/models/circle.dart';
import '../../domain/models/circle_invite.dart';
import '../../domain/models/circle_member.dart';
import '../../domain/repositories/circle_repository.dart';

class SupabaseCircleRepository implements CircleRepository {
  static final SupabaseCircleRepository instance =
      SupabaseCircleRepository._internal();
  SupabaseCircleRepository._internal()
    : _client = SupabaseConfig.isConfigured ? Supabase.instance.client : null;

  final SupabaseClient? _client;

  @override
  Future<Circle> createCircle({
    required String name,
    required String ownerId,
    String? description,
    String? inviteCode,
    String? requestId,
  }) async {
    if (_client != null) {
      final rpcRes = await _client.rpc(
        'create_circle_with_invite',
        params: {
          'p_name': name.trim(),
          'p_description':
              (description != null && description.trim().isNotEmpty)
              ? description.trim()
              : null,
          'p_request_id': (requestId != null && requestId.trim().isNotEmpty)
              ? requestId.trim()
              : null,
        },
      );
      if (rpcRes is Map && rpcRes['circle'] != null) {
        return Circle.fromJson(
          Map<String, dynamic>.from(rpcRes['circle'] as Map),
        );
      }
      throw StateError('Invalid response from create_circle_with_invite');
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      return GufiBackendStore.instance.createCircle(
        name: name,
        ownerId: ownerId,
        description: description,
        inviteCode: inviteCode,
        requestId: requestId,
      );
    }
  }

  @override
  Future<Circle?> getCircle(String circleId) async {
    if (_client != null) {
      final res = await _client
          .from('circles')
          .select()
          .eq('id', circleId)
          .maybeSingle();
      return res != null ? Circle.fromJson(res) : null;
    } else {
      return GufiBackendStore.instance.getCircle(circleId);
    }
  }

  @override
  Future<List<Circle>> getUserCircles(String userId) async {
    if (_client != null) {
      // Fetch circles where user is a member or owner
      final res = await _client
          .from('circles')
          .select('*, circle_members!inner(user_id, status)')
          .eq('circle_members.user_id', userId)
          .eq('circle_members.status', 'active');
      return (res as List).map((row) => Circle.fromJson(row)).toList();
    } else {
      return GufiBackendStore.instance.getUserCircles(userId);
    }
  }

  @override
  Future<CircleMember> addMember({
    required String circleId,
    required String userId,
    CircleMemberRole role = CircleMemberRole.member,
  }) async {
    if (_client != null) {
      final res = await _client
          .from('circle_members')
          .upsert({
            'circle_id': circleId,
            'user_id': userId,
            'role': role.toDbString(),
            'status': 'active',
          })
          .select()
          .single();
      return CircleMember.fromJson(res);
    } else {
      return GufiBackendStore.instance.addCircleMember(
        circleId: circleId,
        userId: userId,
        role: role,
      );
    }
  }

  @override
  Future<void> removeMember({
    required String circleId,
    required String userId,
  }) async {
    if (_client != null) {
      await _client
          .from('circle_members')
          .update({
            'status': 'removed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .match({'circle_id': circleId, 'user_id': userId});
    } else {
      GufiBackendStore.instance.removeCircleMember(
        circleId: circleId,
        userId: userId,
      );
    }
  }

  @override
  Future<List<CircleMember>> getCircleMembers(String circleId) async {
    if (_client != null) {
      final res = await _client
          .from('circle_members')
          .select()
          .eq('circle_id', circleId)
          .eq('status', 'active');
      return (res as List).map((row) => CircleMember.fromJson(row)).toList();
    } else {
      return GufiBackendStore.instance.getCircleMembers(circleId);
    }
  }

  @override
  Future<bool> isUserCircleMember({
    required String circleId,
    required String userId,
  }) async {
    if (_client != null) {
      final res = await _client.from('circle_members').select('id').match({
        'circle_id': circleId,
        'user_id': userId,
        'status': 'active',
      }).maybeSingle();
      return res != null;
    } else {
      return GufiBackendStore.instance.isUserCircleMember(
        circleId: circleId,
        userId: userId,
      );
    }
  }

  @override
  Future<InviteResolutionResult> resolveInvite({
    required String code,
    required String? currentUserId,
  }) async {
    if (_client != null) {
      final normalized = GufiBackendStore.normalizeInviteCode(code);
      if (normalized.isEmpty) return const InviteResolvedInvalid();

      try {
        final rpcRes = await _client.rpc(
          'resolve_circle_invite',
          params: {'p_code': normalized},
        );
        if (rpcRes is Map) {
          final status = rpcRes['status'] as String?;
          if (status == 'invalid') return const InviteResolvedInvalid();
          if (status == 'revoked') return const InviteResolvedRevoked();
          if (status == 'expired') return const InviteResolvedExpired();

          final previewMembers = <CirclePreviewMember>[];
          if (rpcRes['previewMembers'] is List) {
            for (final m in (rpcRes['previewMembers'] as List)) {
              if (m is Map) {
                previewMembers.add(
                  CirclePreviewMember(
                    id: m['id'] as String,
                    displayName: (m['displayName'] as String?) ?? 'Member',
                    profilePhotoUrl: m['profilePhotoUrl'] as String?,
                  ),
                );
              }
            }
          }

          final preview = CirclePreview(
            circleId: rpcRes['circleId'] as String,
            circleName: rpcRes['circleName'] as String,
            description: rpcRes['description'] as String?,
            inviteCode: (rpcRes['inviteCode'] as String?) ?? normalized,
            creatorName: rpcRes['creatorName'] as String?,
            memberCount:
                (rpcRes['memberCount'] as num?)?.toInt() ??
                previewMembers.length,
            previewMembers: previewMembers,
          );

          if (status == 'already_member') {
            return InviteResolvedAlreadyMember(preview);
          }
          return InviteResolvedValid(preview);
        }
      } catch (_) {
        if (kReleaseMode) {
          return const InviteResolvedInvalid();
        }
      }

      if (kReleaseMode) {
        return const InviteResolvedInvalid();
      }

      final res = await _client
          .from('circle_invites')
          .select('*, circles(*)')
          .eq('code', normalized)
          .maybeSingle();

      if (res == null) return const InviteResolvedInvalid();

      final invite = CircleInvite.fromJson(res);
      if (invite.status == CircleInviteStatus.revoked) {
        return const InviteResolvedRevoked();
      }
      if (invite.isExpired) {
        return const InviteResolvedExpired();
      }

      final circleData = res['circles'] as Map<String, dynamic>?;
      if (circleData == null) return const InviteResolvedInvalid();
      final circle = Circle.fromJson(circleData);

      // Fetch safe members
      final membersRes = await _client
          .from('circle_members')
          .select('user_id, users(display_name, username, profile_photo_url)')
          .eq('circle_id', circle.id)
          .eq('status', 'active');

      final previewMembers = <CirclePreviewMember>[];
      for (final row in (membersRes as List)) {
        final userData = row['users'] as Map<String, dynamic>?;
        final name =
            (userData?['display_name'] as String?) ??
            (userData?['username'] as String?) ??
            'Member';
        previewMembers.add(
          CirclePreviewMember(
            id: row['user_id'] as String,
            displayName: name,
            profilePhotoUrl: userData?['profile_photo_url'] as String?,
          ),
        );
      }

      final creatorRes = await _client
          .from('users')
          .select('display_name, username')
          .eq('id', circle.ownerId)
          .maybeSingle();
      final creatorName =
          (creatorRes?['display_name'] as String?) ??
          (creatorRes?['username'] as String?);

      final preview = CirclePreview(
        circleId: circle.id,
        circleName: circle.name,
        description: circle.description,
        inviteCode: invite.code,
        creatorName: creatorName,
        memberCount: previewMembers.length,
        previewMembers: previewMembers,
      );

      if (currentUserId != null) {
        final isMember = await isUserCircleMember(
          circleId: circle.id,
          userId: currentUserId,
        );
        if (isMember) {
          return InviteResolvedAlreadyMember(preview);
        }
      }

      return InviteResolvedValid(preview);
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      return GufiBackendStore.instance.resolveInviteCode(
        code: code,
        currentUserId: currentUserId,
      );
    }
  }

  @override
  Future<JoinCircleResult> joinCircleWithInvite({
    required String code,
    required String userId,
  }) async {
    if (_client != null) {
      final normalized = GufiBackendStore.normalizeInviteCode(code);

      try {
        final rpcRes = await _client.rpc(
          'join_circle_with_invite',
          params: {'p_code': normalized},
        );
        if (rpcRes is Map) {
          final success = rpcRes['success'] == true;
          final status = rpcRes['status'] as String?;
          final circleId = rpcRes['circleId'] as String?;
          if (success && circleId != null) {
            if (status == 'already_member') {
              return JoinCircleAlreadyMember(circleId: circleId);
            }
            return JoinCircleSuccess(circleId: circleId);
          } else {
            final msg =
                (rpcRes['message'] as String?) ?? 'Could not join circle.';
            return JoinCircleFailure(msg);
          }
        }
      } catch (_) {
        if (kReleaseMode) {
          return const JoinCircleFailure(
            'Could not join circle. Please try again.',
          );
        }
      }

      if (kReleaseMode) {
        return const JoinCircleFailure(
          'Could not join circle. Please try again.',
        );
      }

      final res = await _client
          .from('circle_invites')
          .select()
          .eq('code', normalized)
          .maybeSingle();

      if (res == null) {
        return const JoinCircleFailure('We couldn’t find that invite.');
      }
      final invite = CircleInvite.fromJson(res);
      if (invite.status == CircleInviteStatus.revoked) {
        return const JoinCircleFailure('This invite is no longer active.');
      }
      if (invite.isExpired) {
        return const JoinCircleFailure('This invite has expired.');
      }

      final isMember = await isUserCircleMember(
        circleId: invite.circleId,
        userId: userId,
      );
      if (isMember) {
        return JoinCircleAlreadyMember(circleId: invite.circleId);
      }

      await addMember(circleId: invite.circleId, userId: userId);
      // Increment use_count
      await _client
          .from('circle_invites')
          .update({'use_count': invite.useCount + 1})
          .eq('id', invite.id);

      return JoinCircleSuccess(circleId: invite.circleId);
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      return GufiBackendStore.instance.joinCircleWithInvite(
        code: code,
        userId: userId,
      );
    }
  }

  @override
  Future<CircleInvite> createInvite({
    required String circleId,
    required String creatorId,
    String? customCode,
    DateTime? expiresAt,
    int? maxUses,
  }) async {
    if (_client != null) {
      final code = customCode != null && customCode.trim().isNotEmpty
          ? GufiBackendStore.normalizeInviteCode(customCode)
          : GufiBackendStore.instance.generateInviteCode();

      final res = await _client
          .from('circle_invites')
          .insert({
            'circle_id': circleId,
            'code': code,
            'creator_id': creatorId,
            'status': 'active',
            'expires_at': expiresAt?.toIso8601String(),
            'max_uses': maxUses,
            'use_count': 0,
          })
          .select()
          .single();
      return CircleInvite.fromJson(res);
    } else {
      return GufiBackendStore.instance.createCircleInvite(
        circleId: circleId,
        creatorId: creatorId,
        customCode: customCode,
        expiresAt: expiresAt,
        maxUses: maxUses,
      );
    }
  }

  @override
  Future<CircleInvite?> getInviteByCode(String code) async {
    if (_client != null) {
      final normalized = GufiBackendStore.normalizeInviteCode(code);
      final res = await _client
          .from('circle_invites')
          .select()
          .eq('code', normalized)
          .maybeSingle();
      return res != null ? CircleInvite.fromJson(res) : null;
    } else {
      return GufiBackendStore.instance.getInviteByCode(code);
    }
  }

  @override
  Future<CircleInvite?> getActiveInviteForCircle(String circleId) async {
    if (_client != null) {
      final res = await _client
          .from('circle_invites')
          .select()
          .eq('circle_id', circleId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return res != null ? CircleInvite.fromJson(res) : null;
    } else {
      return GufiBackendStore.instance.getActiveInviteForCircle(circleId);
    }
  }

  @override
  Stream<List<CircleMember>> watchCircleMembers(String circleId) {
    if (_client != null) {
      try {
        return _client
            .from('circle_members')
            .stream(primaryKey: ['id'])
            .eq('circle_id', circleId)
            .map(
              (rows) => rows
                  .map((r) => CircleMember.fromJson(r))
                  .where((m) => m.isActive)
                  .toList(),
            );
      } catch (_) {
        if (kReleaseMode) {
          return const Stream.empty();
        }
      }
    }
    if (kReleaseMode) {
      throw StateError('Supabase backend is required in Release mode.');
    }
    return GufiBackendStore.instance.onDataChanged.asyncMap((_) async {
      final members = await getCircleMembers(circleId);
      return members.where((m) => m.isActive).toList();
    });
  }
}
