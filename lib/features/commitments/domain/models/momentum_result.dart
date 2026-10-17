/// Strongly typed representation of Gufi 7-day Momentum.
///
/// Formula:
/// VERIFIED / (VERIFIED + MISSED + CANCELLED) * 100
///
/// Rules:
/// - Cancelled commitments count as NOT KEPT (included in denominator).
/// - Unresolved commitments (draft, committed pending, proof_submitted, rejected in window) are EXCLUDED.
/// - If resolvedCount == 0, momentum is unavailable/neutral, NOT 100%.
class MomentumResult {
  final int? score; // 0 to 100, null if no resolved data
  final int verifiedCount;
  final int missedCount;
  final int cancelledCount;
  final int resolvedCount;
  final bool isAvailable;

  const MomentumResult({
    this.score,
    required this.verifiedCount,
    required this.missedCount,
    required this.cancelledCount,
    required this.resolvedCount,
    required this.isAvailable,
  });

  /// Neutral / unavailable state when user has no resolved commitments in window.
  factory MomentumResult.neutral() {
    return const MomentumResult(
      score: null,
      verifiedCount: 0,
      missedCount: 0,
      cancelledCount: 0,
      resolvedCount: 0,
      isAvailable: false,
    );
  }

  /// Calculates momentum deterministically from counts.
  factory MomentumResult.fromCounts({
    required int verified,
    required int missed,
    required int cancelled,
  }) {
    final resolved = verified + missed + cancelled;
    if (resolved == 0) {
      return MomentumResult.neutral();
    }

    final calculatedScore = ((verified / resolved) * 100.0).round();
    return MomentumResult(
      score: calculatedScore,
      verifiedCount: verified,
      missedCount: missed,
      cancelledCount: cancelled,
      resolvedCount: resolved,
      isAvailable: true,
    );
  }

  factory MomentumResult.fromJson(Map<String, dynamic> json) {
    return MomentumResult(
      score: json['score'] as int?,
      verifiedCount: (json['verified_count'] as num?)?.toInt() ?? 0,
      missedCount: (json['missed_count'] as num?)?.toInt() ?? 0,
      cancelledCount: (json['cancelled_count'] as num?)?.toInt() ?? 0,
      resolvedCount: (json['resolved_count'] as num?)?.toInt() ?? 0,
      isAvailable: json['is_available'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'verified_count': verifiedCount,
      'missed_count': missedCount,
      'cancelled_count': cancelledCount,
      'resolved_count': resolvedCount,
      'is_available': isAvailable,
    };
  }
}
