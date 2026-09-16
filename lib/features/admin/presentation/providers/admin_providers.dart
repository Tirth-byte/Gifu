import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/supabase_admin_repository.dart';

/// Provider for administrative data and operations
final adminRepositoryProvider = Provider<SupabaseAdminRepository>((ref) {
  return SupabaseAdminRepository();
});
