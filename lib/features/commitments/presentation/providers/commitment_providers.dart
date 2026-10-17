import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/supabase_commitment_repository.dart';
import '../../data/repositories/supabase_momentum_repository.dart';
import '../../data/repositories/supabase_proof_repository.dart';
import '../../data/repositories/supabase_review_repository.dart';
import '../../domain/models/commitment.dart';
import '../../domain/models/daily_result.dart';
import '../../domain/models/momentum_result.dart';
import '../../domain/repositories/commitment_repository.dart';
import '../../domain/repositories/momentum_repository.dart';
import '../../domain/repositories/proof_repository.dart';
import '../../domain/repositories/review_repository.dart';
import '../../domain/utils/gufi_day_utils.dart';

final commitmentRepositoryProvider = Provider<CommitmentRepository>((ref) {
  return SupabaseCommitmentRepository.instance;
});

final proofRepositoryProvider = Provider<ProofRepository>((ref) {
  return SupabaseProofRepository.instance;
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return SupabaseReviewRepository.instance;
});

final momentumRepositoryProvider = Provider<MomentumRepository>((ref) {
  return SupabaseMomentumRepository.instance;
});

/// Granular provider for a user's commitments on a specific Gufi day.
final userCommitmentsForDayProvider =
    FutureProvider.family<List<Commitment>, ({String userId, String gufiDay})>((
      ref,
      arg,
    ) async {
      final repo = ref.watch(commitmentRepositoryProvider);
      return repo.getUserCommitmentsForDay(
        userId: arg.userId,
        gufiDay: arg.gufiDay,
      );
    });

/// Provider for user commitments on the current Gufi day.
final todayCommitmentsProvider =
    FutureProvider.family<List<Commitment>, String>((ref, userId) async {
      final currentGufiDay = GufiDayUtils.getGufiDayForTimestamp(
        DateTime.now().toUtc(),
      );
      final repo = ref.watch(commitmentRepositoryProvider);
      return repo.getUserCommitmentsForDay(
        userId: userId,
        gufiDay: currentGufiDay,
      );
    });

/// Granular provider for user daily summary on a given Gufi day.
final dailyResultProvider =
    FutureProvider.family<DailyResult, ({String userId, String gufiDay})>((
      ref,
      arg,
    ) async {
      final repo = ref.watch(momentumRepositoryProvider);
      return repo.getDailyResult(userId: arg.userId, gufiDay: arg.gufiDay);
    });

/// Granular provider for 7-day user momentum.
final userMomentumProvider = FutureProvider.family<MomentumResult, String>((
  ref,
  userId,
) async {
  final currentGufiDay = GufiDayUtils.getGufiDayForTimestamp(
    DateTime.now().toUtc(),
  );
  final repo = ref.watch(momentumRepositoryProvider);
  return repo.getMomentum(userId: userId, currentGufiDay: currentGufiDay);
});
