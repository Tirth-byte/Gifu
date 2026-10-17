import '../models/proof.dart';
import '../models/proof_type.dart';

abstract class ProofRepository {
  /// Submits proof for a committed or rejected commitment.
  /// If submission is successful, status transitions to `proof_submitted`.
  Future<Proof> submitProof({
    required String commitmentId,
    required String submitterId,
    required ProofType proofType,
    String? textContent,
    String? mediaUrl,
  });

  Future<Proof?> getProof(String proofId);

  Future<List<Proof>> getProofsForCommitment(String commitmentId);
}
