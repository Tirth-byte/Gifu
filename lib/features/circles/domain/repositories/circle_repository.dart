import '../models/circle.dart';
import '../models/circle_invite.dart';
import '../models/circle_member.dart';

abstract class CircleRepository {
  Future<Circle> createCircle({
    required String name,
    required String ownerId,
    String? description,
    String? inviteCode,
    String? requestId,
  });

  Future<Circle?> getCircle(String circleId);

  Future<List<Circle>> getUserCircles(String userId);

  Future<CircleMember> addMember({
    required String circleId,
    required String userId,
    CircleMemberRole role = CircleMemberRole.member,
  });

  Future<void> removeMember({required String circleId, required String userId});

  Future<List<CircleMember>> getCircleMembers(String circleId);

  Future<bool> isUserCircleMember({
    required String circleId,
    required String userId,
  });

  Future<InviteResolutionResult> resolveInvite({
    required String code,
    required String? currentUserId,
  });

  Future<JoinCircleResult> joinCircleWithInvite({
    required String code,
    required String userId,
  });

  Future<CircleInvite> createInvite({
    required String circleId,
    required String creatorId,
    String? customCode,
    DateTime? expiresAt,
    int? maxUses,
  });

  Future<CircleInvite?> getInviteByCode(String code);

  Future<CircleInvite?> getActiveInviteForCircle(String circleId);

  Stream<List<CircleMember>> watchCircleMembers(String circleId);
}
