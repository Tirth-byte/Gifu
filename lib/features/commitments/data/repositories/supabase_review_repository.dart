import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/services/gufi_backend_store.dart';
import '../../domain/models/review.dart';
import '../../domain/repositories/review_repository.dart';

class SupabaseReviewRepository implements ReviewRepository {
  static final SupabaseReviewRepository instance =
      SupabaseReviewRepository._internal();
  SupabaseReviewRepository._internal()
    : _client = SupabaseConfig.isConfigured ? Supabase.instance.client : null;

  final SupabaseClient? _client;

  @override
  Future<Review> reviewProof({
    required String proofId,
    required String reviewerId,
    required ReviewDecision decision,
    String? reason,
  }) async {
    if (_client != null) {
      final res = await _client.rpc(
        'review_proof',
        params: {
          'p_proof_id': proofId,
          'p_decision': decision.toDbString(),
          'p_note': reason,
        },
      );

      final reviewId = (res as Map<String, dynamic>)['review_id'] as String;
      final reviewRow = await _client
          .from('reviews')
          .select()
          .eq('id', reviewId)
          .single();
      return Review.fromJson(reviewRow);
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      return GufiBackendStore.instance.reviewProof(
        proofId: proofId,
        reviewerId: reviewerId,
        decision: decision,
        reason: reason,
      );
    }
  }

  @override
  Future<List<Review>> getReviewsForProof(String proofId) async {
    if (_client != null) {
      final res = await _client
          .from('reviews')
          .select()
          .eq('proof_id', proofId)
          .order('created_at', ascending: false);
      return (res as List).map((row) => Review.fromJson(row)).toList();
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      return GufiBackendStore.instance.getReviewsForProof(proofId);
    }
  }

  @override
  Future<List<Review>> getReviewsForCommitment(String commitmentId) async {
    if (_client != null) {
      final res = await _client
          .from('reviews')
          .select()
          .eq('commitment_id', commitmentId)
          .order('created_at', ascending: false);
      return (res as List).map((row) => Review.fromJson(row)).toList();
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      return GufiBackendStore.instance.getReviewsForCommitment(commitmentId);
    }
  }
}
