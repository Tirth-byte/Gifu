import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/supabase_auth_repository.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';

/// Central Auth Repository provider — returns the single shared instance.
///
/// CRITICAL: All app code must use this provider (or SupabaseAuthRepository.instance
/// directly in non-Riverpod contexts like the router). Never call
/// SupabaseAuthRepository() with new — that creates a separate instance with an
/// independent _cachedProfile that will not propagate to the rest of the app.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository.instance;
});

/// Stream of live authentication state changes emitted by the repository.
final authStateChangesProvider = StreamProvider<UserProfile?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

/// Async profile loader with explicit loading / data / error states.
///
/// Resolution order:
/// 1. If the auth stream has already emitted a value → return it immediately (no network).
/// 2. Otherwise → call fetchCurrentProfile() which:
///    - Returns _cachedProfile instantly if available (just logged in / signed up).
///    - Falls back to a Supabase network fetch using currentUser UID.
///
/// This provider is automatically re-evaluated when authStateChangesProvider emits.
final currentUserProfileAsyncProvider = FutureProvider<UserProfile?>((
  ref,
) async {
  // Watch the live stream — when it emits, this future provider re-evaluates.
  final streamValue = ref.watch(authStateChangesProvider);

  if (streamValue is AsyncData<UserProfile?>) {
    // Stream already has a value (either from login event or previous emission).
    return streamValue.value;
  }

  if (streamValue is AsyncError<UserProfile?>) {
    // Stream itself errored — propagate the error with original stack trace.
    Error.throwWithStackTrace(streamValue.error, streamValue.stackTrace);
  }

  // Stream is still loading (AsyncLoading) — fall through to explicit fetch.
  // This handles:
  // - App restart (auth listener not yet fired)
  // - Cold launch where _cachedProfile was already set by a previous session restore
  final repo = ref.read(authRepositoryProvider);
  return repo.fetchCurrentProfile();
});

/// Synchronous convenience provider — current profile or null.
/// Safe for use in widgets that can tolerate null (admin guards, etc.).
final currentUserProfileProvider = Provider<UserProfile?>((ref) {
  final streamValue = ref.watch(authStateChangesProvider);
  if (streamValue is AsyncData<UserProfile?>) return streamValue.value;
  return ref.read(authRepositoryProvider).currentUserProfile;
});

/// True if the authenticated user has confirmed server-side admin privileges.
final isAdminProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentUserProfileProvider);
  return profile != null && profile.isAdmin && profile.isActive;
});
