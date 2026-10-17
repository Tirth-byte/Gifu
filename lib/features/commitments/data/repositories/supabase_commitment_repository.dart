import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/services/gufi_backend_store.dart';
import '../../domain/models/accountability_scope.dart';
import '../../domain/models/commitment.dart';
import '../../domain/models/proof_type.dart';
import '../../domain/repositories/commitment_repository.dart';

class SupabaseCommitmentRepository implements CommitmentRepository {
  static final SupabaseCommitmentRepository instance =
      SupabaseCommitmentRepository._internal();
  SupabaseCommitmentRepository._internal()
    : _client = SupabaseConfig.isConfigured ? Supabase.instance.client : null;

  final SupabaseClient? _client;

  @override
  Future<Commitment> createDraft({
    required String ownerId,
    String? circleId,
    AccountabilityScope? accountabilityScope,
    required String title,
    String? description,
    ProofType? proofType,
    required String gufiDay,
    required DateTime dueAt,
    String timezone = 'UTC',
  }) async {
    final scope =
        accountabilityScope ??
        (circleId != null
            ? AccountabilityScope.circle
            : AccountabilityScope.private);

    if (_client != null) {
      final res = await _client
          .from('commitments')
          .insert({
            'owner_id': ownerId,
            'circle_id': scope.isCircle ? circleId : null,
            'accountability_scope': scope.toDbString(),
            'title': title.trim(),
            'description': description?.trim(),
            if (proofType != null) 'proof_type': proofType.toDbString(),
            'gufi_day': gufiDay,
            'due_at': dueAt.toIso8601String(),
            'timezone': timezone,
            'status': 'draft',
          })
          .select()
          .single();
      return Commitment.fromJson(res);
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      return GufiBackendStore.instance.createDraftCommitment(
        ownerId: ownerId,
        circleId: scope.isCircle ? circleId : null,
        accountabilityScope: scope,
        title: title,
        description: description,
        proofType: proofType,
        gufiDay: gufiDay,
        dueAt: dueAt,
        timezone: timezone,
      );
    }
  }

  @override
  Future<Commitment> updateDraft({
    required String commitmentId,
    required String ownerId,
    String? circleId,
    AccountabilityScope? accountabilityScope,
    String? title,
    String? description,
    ProofType? proofType,
    DateTime? dueAt,
  }) async {
    if (_client != null) {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (circleId != null) updateData['circle_id'] = circleId;
      if (accountabilityScope != null) {
        updateData['accountability_scope'] = accountabilityScope.toDbString();
      }
      if (title != null) updateData['title'] = title.trim();
      if (description != null) updateData['description'] = description.trim();
      if (proofType != null) updateData['proof_type'] = proofType.toDbString();
      if (dueAt != null) updateData['due_at'] = dueAt.toIso8601String();

      final res = await _client
          .from('commitments')
          .update(updateData)
          .match({'id': commitmentId, 'owner_id': ownerId, 'status': 'draft'})
          .select()
          .single();
      return Commitment.fromJson(res);
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      return GufiBackendStore.instance.updateDraftCommitment(
        commitmentId: commitmentId,
        ownerId: ownerId,
        circleId: circleId,
        accountabilityScope: accountabilityScope,
        title: title,
        description: description,
        proofType: proofType,
        dueAt: dueAt,
      );
    }
  }

  @override
  Future<void> deleteDraft({
    required String commitmentId,
    required String ownerId,
  }) async {
    if (_client != null) {
      await _client.from('commitments').delete().match({
        'id': commitmentId,
        'owner_id': ownerId,
        'status': 'draft',
      });
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      GufiBackendStore.instance.deleteDraftCommitment(
        commitmentId: commitmentId,
        ownerId: ownerId,
      );
    }
  }

  @override
  Future<Commitment> commit(String commitmentId) async {
    if (_client != null) {
      // Calls atomic server-side RPC that enforces max 3 commitments per Gufi day
      await _client.rpc(
        'commit_commitment',
        params: {'p_commitment_id': commitmentId},
      );

      final res = await _client
          .from('commitments')
          .select()
          .eq('id', commitmentId)
          .single();
      return Commitment.fromJson(res);
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      return GufiBackendStore.instance.commitCommitment(commitmentId);
    }
  }

  @override
  Future<Commitment> cancelCommitment({
    required String commitmentId,
    required String ownerId,
    String? reason,
  }) async {
    if (_client != null) {
      await _client.rpc(
        'cancel_commitment',
        params: {'p_commitment_id': commitmentId},
      );

      final res = await _client
          .from('commitments')
          .select()
          .eq('id', commitmentId)
          .single();
      return Commitment.fromJson(res);
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      return GufiBackendStore.instance.cancelCommitment(
        commitmentId: commitmentId,
        ownerId: ownerId,
        reason: reason,
      );
    }
  }

  @override
  Future<Commitment?> getCommitment(String commitmentId) async {
    if (_client != null) {
      final res = await _client
          .from('commitments')
          .select()
          .eq('id', commitmentId)
          .maybeSingle();
      return res != null ? Commitment.fromJson(res) : null;
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      return GufiBackendStore.instance.getCommitment(commitmentId);
    }
  }

  @override
  Future<List<Commitment>> getUserCommitmentsForDay({
    required String userId,
    required String gufiDay,
  }) async {
    if (_client != null) {
      final res = await _client
          .from('commitments')
          .select()
          .eq('owner_id', userId)
          .eq('gufi_day', gufiDay)
          .order('created_at');
      return (res as List).map((row) => Commitment.fromJson(row)).toList();
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      return GufiBackendStore.instance.getUserCommitmentsForDay(
        userId: userId,
        gufiDay: gufiDay,
      );
    }
  }

  @override
  Future<List<Commitment>> getCircleCommitmentsForDay({
    required String circleId,
    required String gufiDay,
  }) async {
    if (_client != null) {
      final res = await _client
          .from('commitments')
          .select()
          .eq('circle_id', circleId)
          .eq('gufi_day', gufiDay)
          .neq('status', 'draft')
          .order('created_at');
      return (res as List).map((row) => Commitment.fromJson(row)).toList();
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      return GufiBackendStore.instance.getCircleCommitmentsForDay(
        circleId: circleId,
        gufiDay: gufiDay,
      );
    }
  }

  @override
  Future<int> evaluateMissedCommitments() async {
    if (_client != null) {
      final res = await _client.rpc('evaluate_missed_commitments');
      return (res as num?)?.toInt() ?? 0;
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      return GufiBackendStore.instance.evaluateMissedCommitments();
    }
  }
}
