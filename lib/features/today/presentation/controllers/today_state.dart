import 'package:gufi/features/auth/domain/models/user_profile.dart';
import 'package:gufi/features/commitments/domain/models/commitment.dart';
import 'package:gufi/features/commitments/domain/models/commitment_status.dart';
import 'package:gufi/features/commitments/domain/models/daily_result.dart';
import 'package:gufi/features/commitments/domain/models/momentum_result.dart';

import '../../domain/models/review_request_item.dart';

/// Single unified state for the Gufi Today screen.
class TodayState {
  final UserProfile? currentUser;
  final String gufiDay;
  final MomentumResult? momentum;
  final List<Commitment> commitments;
  final DailyResult? dailyResult;
  final List<ReviewRequestItem> reviewRequests;
  final Map<String, String> verifierNamesByCommitmentId;
  final bool loading;
  final String? error;

  const TodayState({
    this.currentUser,
    this.gufiDay = '',
    this.momentum,
    this.commitments = const [],
    this.dailyResult,
    this.reviewRequests = const [],
    this.verifierNamesByCommitmentId = const {},
    this.loading = true,
    this.error,
  });

  int get totalCount => commitments.length;

  int get verifiedCount =>
      commitments.where((c) => c.status == CommitmentStatus.verified).length;

  int get inMotionCount => commitments
      .where(
        (c) =>
            c.status == CommitmentStatus.committed ||
            c.status == CommitmentStatus.proofSubmitted ||
            c.status == CommitmentStatus.rejected,
      )
      .length;

  int get missedCount =>
      commitments.where((c) => c.status == CommitmentStatus.missed).length;

  int get cancelledCount =>
      commitments.where((c) => c.status == CommitmentStatus.cancelled).length;

  bool get canCreateCommitment => commitments.length < 3;

  bool get allVerified => totalCount > 0 && verifiedCount == totalCount;

  /// Deterministic headline generator adhering strictly to Gufi product copy rules:
  /// - 0 commitments: "Your day is open."
  /// - 1 commitment active: "One promise.\nMake it count."
  /// - 1 commitment verified: "You showed up\nfor today."
  /// - All verified (2 or 3): "You showed up\nfor all $total."
  /// - Unresolved: "$inMotion of $total promises\nstill in motion." or "$total promises\nin motion."
  /// - All resolved mixed: "Today is written."
  String get heroHeadline {
    if (totalCount == 0) {
      return 'Your day is open.';
    }

    if (totalCount == 1) {
      if (verifiedCount == 1) {
        return 'You showed up\nfor today.';
      }
      if (inMotionCount == 1) {
        return 'One promise.\nMake it count.';
      }
      return 'Today is written.';
    }

    // 2 or 3 commitments
    if (verifiedCount == totalCount) {
      return 'You showed up\nfor all $totalCount.';
    }

    if (inMotionCount > 0) {
      if (inMotionCount == totalCount) {
        return '$totalCount promises\nin motion.';
      }
      return '$inMotionCount of $totalCount promises\nstill in motion.';
    }

    return 'Today is written.';
  }

  String? get heroSubtitle {
    if (totalCount == 0) {
      return 'Make one promise worth keeping.';
    }
    return null;
  }

  TodayState copyWith({
    UserProfile? currentUser,
    String? gufiDay,
    MomentumResult? momentum,
    bool clearMomentum = false,
    List<Commitment>? commitments,
    DailyResult? dailyResult,
    List<ReviewRequestItem>? reviewRequests,
    Map<String, String>? verifierNamesByCommitmentId,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return TodayState(
      currentUser: currentUser ?? this.currentUser,
      gufiDay: gufiDay ?? this.gufiDay,
      momentum: clearMomentum ? null : (momentum ?? this.momentum),
      commitments: commitments ?? this.commitments,
      dailyResult: dailyResult ?? this.dailyResult,
      reviewRequests: reviewRequests ?? this.reviewRequests,
      verifierNamesByCommitmentId:
          verifierNamesByCommitmentId ?? this.verifierNamesByCommitmentId,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
