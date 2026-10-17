import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/haptics/app_haptics.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../commitments/domain/models/proof_type.dart';
import '../../../commitments/domain/models/review.dart';
import '../../domain/models/review_request_item.dart';

/// Minimum real proof review modal:
/// Shows commitment title, submitter info, submitted proof (photo/text), timestamp.
/// Actions:
/// - "Looks good" -> Approved
/// - "Ask for another proof" -> Rejected with required reason.
class ReviewProofSheet extends StatefulWidget {
  const ReviewProofSheet({
    super.key,
    required this.item,
    required this.onReview,
  });

  final ReviewRequestItem item;
  final Future<void> Function({
    required ReviewDecision decision,
    String? reason,
  })
  onReview;

  @override
  State<ReviewProofSheet> createState() => _ReviewProofSheetState();
}

class _ReviewProofSheetState extends State<ReviewProofSheet> {
  bool _rejectMode = false;
  final TextEditingController _reasonController = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  static const Color gufiNavy = Color(0xFF1E3365);
  static const Color limeAccent = Color(0xFFC9F17E);
  static const Color warningAmber = Color(0xFFD97706);

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleApprove() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      AppHaptics.light();
      await widget.onReview(decision: ReviewDecision.approved);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _handleReject() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(
        () => _errorMessage = 'Please provide a reason to help your friend.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      AppHaptics.light();
      await widget.onReview(decision: ReviewDecision.rejected, reason: reason);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final proof = widget.item.proof;
    final isPhoto = proof.proofType == ProofType.photo;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: gufiNavy.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Header: Submitter + Commitment title
            Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.submitterName,
                        style: AppTypography.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: gufiNavy,
                        ),
                      ),
                      Text(
                        'Submitted ${_formatTime(proof.createdAt)}',
                        style: AppTypography.inter(
                          fontSize: 12,
                          color: gufiNavy.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Commitment Title
            Text(
              widget.item.commitment.title,
              style: TextStyle(
                fontFamily: AppTypography.gambarinoFontFamily,
                fontSize: 22,
                fontWeight: FontWeight.w400,
                color: gufiNavy,
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 16),

            // Proof display
            if (isPhoto && proof.mediaUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 220,
                  width: double.infinity,
                  color: const Color(0xFFFAFBFC),
                  child: _buildProofImage(proof.mediaUrl!),
                ),
              ),
            ] else if (proof.textContent != null &&
                proof.textContent!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFBFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: gufiNavy.withValues(alpha: 0.08)),
                ),
                child: Text(
                  proof.textContent!,
                  style: AppTypography.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: gufiNavy,
                    height: 1.4,
                  ),
                ),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: AppTypography.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Reject reason mode
            if (_rejectMode) ...[
              Text(
                'What needs another look?',
                style: AppTypography.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: gufiNavy,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                autofocus: true,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                style: AppTypography.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: gufiNavy,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Please share a clearer photo of the notes',
                  hintStyle: AppTypography.inter(
                    fontSize: 14,
                    color: gufiNavy.withValues(alpha: 0.35),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: gufiNavy.withValues(alpha: 0.1),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _rejectMode = false),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        side: BorderSide(
                          color: gufiNavy.withValues(alpha: 0.2),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Back',
                        style: AppTypography.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: gufiNavy,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _handleReject,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: warningAmber,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Send feedback',
                              style: AppTypography.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Default Actions: "Looks good" (Lime/Green) & "Ask for another proof"
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => setState(() => _rejectMode = true),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        side: BorderSide(
                          color: gufiNavy.withValues(alpha: 0.2),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        'Ask for another proof',
                        style: AppTypography.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: gufiNavy,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _handleApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: limeAccent,
                        foregroundColor: gufiNavy,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  gufiNavy,
                                ),
                              ),
                            )
                          : Text(
                              'Looks good',
                              style: AppTypography.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: gufiNavy,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final avatarUrl = widget.item.submitterAvatarUrl;
    final initial = widget.item.submitterName.isNotEmpty
        ? widget.item.submitterName[0].toUpperCase()
        : 'F';

    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFBCDBFA),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl != null && avatarUrl.isNotEmpty
          ? Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildInitial(initial),
            )
          : _buildInitial(initial),
    );
  }

  Widget _buildInitial(String initial) {
    return Center(
      child: Text(
        initial,
        style: AppTypography.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: gufiNavy,
        ),
      ),
    );
  }

  Widget _buildProofImage(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image_rounded, size: 36, color: gufiNavy),
        ),
      );
    } else {
      // Local file
      final file = File(url);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
      return const Center(
        child: Icon(Icons.photo_rounded, size: 36, color: gufiNavy),
      );
    }
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}
