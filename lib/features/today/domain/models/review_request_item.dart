import 'package:gufi/features/commitments/domain/models/commitment.dart';
import 'package:gufi/features/commitments/domain/models/proof.dart';

/// Item representing a peer's proof awaiting review by the current user.
class ReviewRequestItem {
  final Proof proof;
  final Commitment commitment;
  final String submitterName;
  final String submitterUsername;
  final String? submitterAvatarUrl;

  const ReviewRequestItem({
    required this.proof,
    required this.commitment,
    required this.submitterName,
    required this.submitterUsername,
    this.submitterAvatarUrl,
  });
}
