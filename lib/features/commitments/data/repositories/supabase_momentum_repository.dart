import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/services/gufi_backend_store.dart';
import '../../domain/models/daily_result.dart';
import '../../domain/models/momentum_result.dart';
import '../../domain/repositories/momentum_repository.dart';

class SupabaseMomentumRepository implements MomentumRepository {
  static final SupabaseMomentumRepository instance =
      SupabaseMomentumRepository._internal();
  SupabaseMomentumRepository._internal()
    : _client = SupabaseConfig.isConfigured ? Supabase.instance.client : null;

  final SupabaseClient? _client;

  @override
  Future<MomentumResult> getMomentum({
    required String userId,
    required String currentGufiDay,
  }) async {
    if (_client != null) {
      final res = await _client.rpc(
        'get_user_momentum',
        params: {'p_user_id': userId},
      );
      return MomentumResult.fromJson(res as Map<String, dynamic>);
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      return GufiBackendStore.instance.getMomentum(
        userId: userId,
        currentGufiDay: currentGufiDay,
      );
    }
  }

  @override
  Future<DailyResult> getDailyResult({
    required String userId,
    required String gufiDay,
  }) async {
    if (_client != null) {
      final res = await _client.from('daily_results').select().match({
        'user_id': userId,
        'gufi_day': gufiDay,
      }).maybeSingle();
      if (res != null) {
        return DailyResult.fromJson(res);
      }
      // If not yet materialized, compute live
      await _client.rpc(
        'recalculate_daily_result',
        params: {'p_user_id': userId, 'p_gufi_day': gufiDay},
      );
      final updated = await _client.from('daily_results').select().match({
        'user_id': userId,
        'gufi_day': gufiDay,
      }).single();
      return DailyResult.fromJson(updated);
    } else {
      if (kReleaseMode) {
        throw StateError('Supabase backend is required in Release mode.');
      }
      return GufiBackendStore.instance.getDailyResult(
        userId: userId,
        gufiDay: gufiDay,
      );
    }
  }
}
