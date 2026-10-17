import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/supabase_circle_repository.dart';
import '../../domain/models/circle.dart';
import '../../domain/models/circle_member.dart';
import '../../domain/repositories/circle_repository.dart';

final circleRepositoryProvider = Provider<CircleRepository>((ref) {
  return SupabaseCircleRepository.instance;
});

final userCirclesProvider = FutureProvider.family<List<Circle>, String>((
  ref,
  userId,
) async {
  final repo = ref.watch(circleRepositoryProvider);
  return repo.getUserCircles(userId);
});

final circleMembersProvider = FutureProvider.family<List<CircleMember>, String>(
  (ref, circleId) async {
    final repo = ref.watch(circleRepositoryProvider);
    return repo.getCircleMembers(circleId);
  },
);
