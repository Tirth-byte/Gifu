import '../models/daily_result.dart';
import '../models/momentum_result.dart';

abstract class MomentumRepository {
  /// Computes 7-day Momentum: VERIFIED / (VERIFIED + MISSED + CANCELLED) * 100
  /// Window: [currentGufiDay - 6 days, currentGufiDay].
  Future<MomentumResult> getMomentum({
    required String userId,
    required String currentGufiDay,
  });

  /// Retrieves or recalculates the daily result summary for [userId] on [gufiDay].
  Future<DailyResult> getDailyResult({
    required String userId,
    required String gufiDay,
  });
}
