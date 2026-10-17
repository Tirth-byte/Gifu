import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../commitments/domain/models/proof_type.dart';
import '../../domain/models/review_request_item.dart';

/// Visually distinct soft-blue peer review block on Gufi Today.
/// Human language: "[Name] needs you."
/// Quotes commitment title.
/// Shows proof indicator and "Review proof →" action.
class FriendReviewCard extends StatelessWidget {
  const FriendReviewCard({
    super.key,
    required this.item,
    this.totalWaitingCount = 1,
    required this.onReviewTap,
  });

  final ReviewRequestItem item;
  final int totalWaitingCount;
  final VoidCallback onReviewTap;

  static const Color softBlueSurface = Color(0xFFE8F2FD);
  static const Color borderBlue = Color(0xFFBCDBFA);
  static const Color primaryBlue = Color(0xFF5880DA);
  static const Color gufiNavy = Color(0xFF1E3365);

  @override
  Widget build(BuildContext context) {
    final extraWaiting = totalWaitingCount - 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: softBlueSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderBlue, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Avatar + "[Name] needs you."
          Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.submitterName} needs you.',
                      style: AppTypography.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: gufiNavy,
                      ),
                    ),
                    if (extraWaiting > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$extraWaiting more waiting',
                        style: AppTypography.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: primaryBlue,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Commitment Title in quotes
          Text(
            '"${item.commitment.title}"',
            style: AppTypography.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: gufiNavy.withValues(alpha: 0.85),
            ).copyWith(fontStyle: FontStyle.italic),
          ),

          const SizedBox(height: 14),

          // Action row: Proof type indicator + "Review proof →"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Proof indicator
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.commitment.proofType == ProofType.photo
                        ? Icons.photo_camera_rounded
                        : Icons.notes_rounded,
                    size: 14,
                    color: primaryBlue,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    item.commitment.proofType == ProofType.photo
                        ? 'Photo proof'
                        : 'Text proof',
                    style: AppTypography.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: primaryBlue,
                    ),
                  ),
                ],
              ),

              // CTA button
              InkWell(
                onTap: onReviewTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Review proof',
                        style: AppTypography.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: primaryBlue,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final avatarUrl = item.submitterAvatarUrl;
    final initial = item.submitterName.isNotEmpty
        ? item.submitterName[0].toUpperCase()
        : 'F';

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: borderBlue,
        border: Border.all(
          color: primaryBlue.withValues(alpha: 0.2),
          width: 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl != null && avatarUrl.isNotEmpty
          ? Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildFallbackInitial(initial),
            )
          : _buildFallbackInitial(initial),
    );
  }

  Widget _buildFallbackInitial(String initial) {
    return Center(
      child: Text(
        initial,
        style: AppTypography.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: gufiNavy,
        ),
      ),
    );
  }
}
