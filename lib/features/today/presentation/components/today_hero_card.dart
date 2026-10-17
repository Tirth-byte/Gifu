import 'package:flutter/material.dart';

import '../../../../core/theme/app_typography.dart';
import '../../../commitments/domain/models/commitment.dart';
import '../../../commitments/domain/models/commitment_status.dart';
import '../controllers/today_state.dart';

/// Hero Today card for the Gufi Today screen.
/// Follows the approved Gufi visual direction:
/// - Rounded rectangle (margin 20–24px, radius 28–32px)
/// - Primary surface: #5880DA
/// - Soft tonal variation: #BCDBFA & restrained off-white highlights
/// - Lightweight vector layout geometry conveying forward path/movement
/// - Gambarino for "Today" and hero headline
/// - Sans-serif for date, momentum, and progress details
class TodayHeroCard extends StatelessWidget {
  const TodayHeroCard({super.key, required this.state});

  final TodayState state;

  static const Color primaryBlue = Color(0xFF5880DA);
  static const Color softBlue = Color(0xFFBCDBFA);
  static const Color limeAccent = Color(0xFFC9F17E);
  static const Color gufiNavy = Color(0xFF1E3365);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: primaryBlue,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: gufiNavy.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Subtle vector geometry: restrained concentric paths conveying forward movement & growth
          Positioned.fill(child: CustomPaint(painter: _HeroVectorPainter())),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 26, 26, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top row: Gambarino "Today" + Real formatted date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'Today',
                      style: TextStyle(
                        fontFamily: AppTypography.gambarinoFontFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      _formattedDate(),
                      style: AppTypography.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: softBlue,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // Main headline (Gambarino)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        state.heroHeadline,
                        style: TextStyle(
                          fontFamily: AppTypography.gambarinoFontFamily,
                          fontSize: 32,
                          fontWeight: FontWeight.w400,
                          color: Colors.white,
                          height: 1.14,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    if (state.allVerified) ...[
                      const SizedBox(width: 8),
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: limeAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),

                // Subtitle if empty day
                if (state.heroSubtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    state.heroSubtitle!,
                    style: AppTypography.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: softBlue,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],

                const SizedBox(height: 26),

                // Bottom row: Momentum stat + Promise state markers
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Momentum display (secondary, no giant gauge)
                    _buildMomentumBadge(),

                    // Progress markers (up to 3, one per real commitment)
                    if (state.commitments.isNotEmpty)
                      _buildProgressMarkers(state.commitments),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMomentumBadge() {
    final momentum = state.momentum;
    final isAvailable =
        momentum != null && momentum.isAvailable && momentum.score != null;

    final text = isAvailable
        ? '${momentum.score}% Momentum · 7 days'
        : 'Momentum starts\nwith your first promise.';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isAvailable) ...[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: (momentum.score ?? 0) >= 80 ? limeAccent : softBlue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
        ],
        Text(
          text,
          style: AppTypography.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.85),
            height: 1.25,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressMarkers(List<Commitment> commitments) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: commitments.map((c) {
        return Container(
          margin: const EdgeInsets.only(left: 6),
          width: 8,
          height: 8,
          decoration: _markerDecoration(c.status),
        );
      }).toList(),
    );
  }

  BoxDecoration _markerDecoration(CommitmentStatus status) {
    switch (status) {
      case CommitmentStatus.verified:
      case CommitmentStatus.completed:
        return const BoxDecoration(color: limeAccent, shape: BoxShape.circle);
      case CommitmentStatus.proofSubmitted:
        return const BoxDecoration(color: softBlue, shape: BoxShape.circle);
      case CommitmentStatus.committed:
        return BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        );
      case CommitmentStatus.rejected:
        return BoxDecoration(
          color: const Color(0xFFFBBF24), // restrained warm amber
          shape: BoxShape.circle,
        );
      case CommitmentStatus.missed:
        return BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.4),
            width: 1.5,
          ),
        );
      case CommitmentStatus.cancelled:
      case CommitmentStatus.draft:
        return BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
        );
    }
  }

  String _formattedDate() {
    final now = DateTime.now();
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    return '$weekday · ${now.day} $month';
  }
}

/// Lightweight vector painter rendering restrained forward-movement arcs.
/// Extremely cheap for 120Hz scrolling: static single-draw, no shaders, no blur.
class _HeroVectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBCDBFA).withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Elegant concentric arcs sweeping upwards and rightwards
    final center = Offset(size.width * 0.85, size.height * 1.15);
    canvas.drawCircle(center, size.width * 0.55, paint);
    canvas.drawCircle(center, size.width * 0.82, paint);

    // Subtle highlighted node
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    final nodeOffset = Offset(size.width * 0.72, size.height * 0.25);
    canvas.drawCircle(nodeOffset, 3.5, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
