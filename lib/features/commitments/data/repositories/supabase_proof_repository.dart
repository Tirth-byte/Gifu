import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/services/gufi_backend_store.dart';
import '../../domain/models/proof.dart';
import '../../domain/models/proof_type.dart';
import '../../domain/repositories/proof_repository.dart';

class SupabaseProofRepository implements ProofRepository {
  static final SupabaseProofRepository instance =
      SupabaseProofRepository._internal();
  SupabaseProofRepository._internal()
    : _client = SupabaseConfig.isConfigured ? Supabase.instance.client : null;

  final SupabaseClient? _client;

  /// Upload photo proof to private 'proofs' bucket conforming to path contract:
  /// {circleId}/{commitmentId}/{filename}
  Future<String> uploadPhotoProof({
    required String circleId,
    required String commitmentId,
    required File file,
  }) async {
    if (_client != null) {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${file.uri.pathSegments.last}';
      final storagePath = '$circleId/$commitmentId/$fileName';
      await _client.storage
          .from('proofs')
          .upload(
            storagePath,
            file,
            fileOptions: const FileOptions(upsert: true),
          );
      return storagePath;
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      return file.path;
    }
  }

  @override
  Future<Proof> submitProof({
    required String commitmentId,
    required String submitterId,
    required ProofType proofType,
    String? textContent,
    String? mediaUrl,
  }) async {
    if (_client != null) {
      final res = await _client.rpc(
        'submit_proof',
        params: {
          'p_commitment_id': commitmentId,
          'p_proof_type': proofType.toDbString(),
          'p_text_content': textContent,
          'p_photo_path': mediaUrl,
        },
      );

      final proofId = (res as Map<String, dynamic>)['proof_id'] as String;
      final proofRow = await _client
          .from('proofs')
          .select()
          .eq('id', proofId)
          .single();
      return Proof.fromJson(proofRow);
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      return GufiBackendStore.instance.submitProof(
        commitmentId: commitmentId,
        submitterId: submitterId,
        proofType: proofType,
        textContent: textContent,
        mediaUrl: mediaUrl,
      );
    }
  }

  @override
  Future<Proof?> getProof(String proofId) async {
    if (_client != null) {
      final res = await _client
          .from('proofs')
          .select()
          .eq('id', proofId)
          .maybeSingle();
      return res != null ? Proof.fromJson(res) : null;
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      return GufiBackendStore.instance.getProof(proofId);
    }
  }

  @override
  Future<List<Proof>> getProofsForCommitment(String commitmentId) async {
    if (_client != null) {
      final res = await _client
          .from('proofs')
          .select()
          .eq('commitment_id', commitmentId)
          .order('created_at', ascending: false);
      return (res as List).map((row) => Proof.fromJson(row)).toList();
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      return GufiBackendStore.instance.getProofsForCommitment(commitmentId);
    }
  }
}
