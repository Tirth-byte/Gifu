import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../commitments/domain/models/commitment.dart';
import '../../../commitments/domain/models/commitment_status.dart';

/// Clean rounded grouped commitment row card for Gufi Today.
/// No generic heavy cards with huge shadows.
/// Easy to scan, crisp typography, restrained visual states.
class TodayCommitmentCard extends StatelessWidget {
  const TodayCommitmentCard({
    super.key,
    required this.commitment,
    this.verifierName,
    this.onAddProof,
    this.onComplete,
  });

  final Commitment commitment;
  final String? verifierName;
  final VoidCallback? onAddProof;
  final VoidCallback? onComplete;

  VoidCallback? get _actionCallback => onComplete ?? onAddProof;

  static const Color gufiNavy = Color(0xFF1E3365);
  static const Color primaryBlue = Color(0xFF5880DA);
  static const Color softBlue = Color(0xFFBCDBFA);
  static const Color limeAccent = Color(0xFFC9F17E);
  static const Color warningAmber = Color(0xFFD97706);
  static const Color mutedText = Color(0xFF768B9E);

  @override
  Widget build(BuildContext context) {
    final status = commitment.status;
    final canPerformAction =
        status == CommitmentStatus.committed ||
        status == CommitmentStatus.rejected;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gufiNavy.withValues(alpha: 0.08), width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // State Indicator Icon
          _buildStateIndicator(status),

          const SizedBox(width: 14),

          // Title & Secondary State Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Commitment Title (17-19px sans-serif medium/semibold)
                Text(
                  commitment.title,
                  style: AppTypography.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: gufiNavy,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),

                // Secondary State Text
                Text(
                  _secondaryStateText(status),
                  style: AppTypography.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _secondaryTextColor(status),
                  ),
                ),
              ],
            ),
          ),

          // Contextual Action Button (I did it → or Resubmit →)
          if (canPerformAction) ...[
            const SizedBox(width: 10),
            _buildActionButton(status),
          ],
        ],
      ),
    );
  }

  Widget _buildStateIndicator(CommitmentStatus status) {
    switch (status) {
      case CommitmentStatus.verified:
      case CommitmentStatus.completed:
        return Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: limeAccent,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, size: 16, color: gufiNavy),
        );

      case CommitmentStatus.proofSubmitted:
        return Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: softBlue,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.hourglass_top_rounded,
            size: 14,
            color: gufiNavy,
          ),
        );

      case CommitmentStatus.committed:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: primaryBlue, width: 2.0),
          ),
        );

      case CommitmentStatus.rejected:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: warningAmber.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: warningAmber, width: 1.5),
          ),
          child: const Icon(
            Icons.priority_high_rounded,
            size: 14,
            color: warningAmber,
          ),
        );

      case CommitmentStatus.missed:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFEE2E2),
            border: Border.all(
              color: const Color(0xFFDC2626).withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.close_rounded,
            size: 14,
            color: Color(0xFFDC2626),
          ),
        );

      case CommitmentStatus.cancelled:
      case CommitmentStatus.draft:
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: mutedText.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: const Icon(Icons.remove_rounded, size: 14, color: mutedText),
        );
    }
  }

  String _secondaryStateText(CommitmentStatus status) {
    if (commitment.isPrivate) {
      switch (status) {
        case CommitmentStatus.committed:
          return 'Private';
        case CommitmentStatus.completed:
          return 'Completed';
        case CommitmentStatus.missed:
          return 'Missed';
        case CommitmentStatus.cancelled:
          return 'Cancelled';
        case CommitmentStatus.draft:
          return 'Draft';
        default:
          return 'Private';
      }
    }

    switch (status) {
      case CommitmentStatus.committed:
        return 'In progress';
      case CommitmentStatus.completed:
        return 'Completed';
      case CommitmentStatus.proofSubmitted:
        if (verifierName != null && verifierName!.isNotEmpty) {
          return 'Waiting for $verifierName';
        }
        return 'Waiting for review';
      case CommitmentStatus.verified:
        if (verifierName != null && verifierName!.isNotEmpty) {
          return 'Verified by $verifierName ✓';
        }
        return 'Verified ✓';
      case CommitmentStatus.rejected:
        return 'Proof needs another look';
      case CommitmentStatus.missed:
        return 'Missed';
      case CommitmentStatus.cancelled:
        return 'Cancelled';
      case CommitmentStatus.draft:
        return 'Draft';
    }
  }

  Color _secondaryTextColor(CommitmentStatus status) {
    switch (status) {
      case CommitmentStatus.verified:
      case CommitmentStatus.completed:
        return const Color(0xFF15803D); // restrained forest green
      case CommitmentStatus.proofSubmitted:
        return primaryBlue;
      case CommitmentStatus.rejected:
        return warningAmber;
      case CommitmentStatus.missed:
        return const Color(0xFFB91C1C);
      case CommitmentStatus.committed:
      case CommitmentStatus.cancelled:
      case CommitmentStatus.draft:
        return mutedText;
    }
  }

  Widget _buildActionButton(CommitmentStatus status) {
    final isRejected = status == CommitmentStatus.rejected;
    final label = isRejected ? 'Resubmit →' : 'I did it →';

    return InkWell(
      onTap: _actionCallback,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isRejected
              ? warningAmber.withValues(alpha: 0.1)
              : primaryBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRejected
                ? warningAmber.withValues(alpha: 0.3)
                : primaryBlue.withValues(alpha: 0.2),
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isRejected ? warningAmber : primaryBlue,
          ),
        ),
      ),
    );
  }
}
