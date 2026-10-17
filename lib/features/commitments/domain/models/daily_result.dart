enum DailyStatus {
  empty,
  inProgress,
  pendingReview,
  complete,
  partial,
  missed;

  static DailyStatus fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'empty':
        return DailyStatus.empty;
      case 'in_progress':
      case 'inprogress':
        return DailyStatus.inProgress;
      case 'pending_review':
      case 'pendingreview':
        return DailyStatus.pendingReview;
      case 'complete':
        return DailyStatus.complete;
      case 'partial':
        return DailyStatus.partial;
      case 'missed':
        return DailyStatus.missed;
      default:
        throw ArgumentError('Unknown DailyStatus: $value');
    }
  }

  String toDbString() {
    switch (this) {
      case DailyStatus.inProgress:
        return 'in_progress';
      case DailyStatus.pendingReview:
        return 'pending_review';
      default:
        return name;
    }
  }
}

class DailyResult {
  final String userId;
  final String gufiDay;
  final int commitmentsTotal;
  final int verifiedCount;
  final int missedCount;
  final int cancelledCount;
  final int pendingCount;
  final double completionPercentage;
  final DailyStatus dailyStatus;
  final DateTime updatedAt;

  const DailyResult({
    required this.userId,
    required this.gufiDay,
    this.commitmentsTotal = 0,
    this.verifiedCount = 0,
    this.missedCount = 0,
    this.cancelledCount = 0,
    this.pendingCount = 0,
    this.completionPercentage = 0.0,
    this.dailyStatus = DailyStatus.empty,
    required this.updatedAt,
  });

  factory DailyResult.fromJson(Map<String, dynamic> json) {
    return DailyResult(
      userId: json['user_id'] as String,
      gufiDay: json['gufi_day'] as String,
      commitmentsTotal: (json['commitments_total'] as num?)?.toInt() ?? 0,
      verifiedCount: (json['verified_count'] as num?)?.toInt() ?? 0,
      missedCount: (json['missed_count'] as num?)?.toInt() ?? 0,
      cancelledCount: (json['cancelled_count'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      completionPercentage:
          (json['completion_percentage'] as num?)?.toDouble() ?? 0.0,
      dailyStatus: DailyStatus.fromString(
        (json['daily_status'] as String?) ?? 'empty',
      ),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'gufi_day': gufiDay,
      'commitments_total': commitmentsTotal,
      'verified_count': verifiedCount,
      'missed_count': missedCount,
      'cancelled_count': cancelledCount,
      'pending_count': pendingCount,
      'completion_percentage': completionPercentage,
      'daily_status': dailyStatus.toDbString(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
