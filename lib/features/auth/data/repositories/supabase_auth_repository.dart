import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/services/disposable_email_service.dart';
import '../../../../core/services/gufi_backend_store.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/auth_repository.dart';

/// Real implementation of AuthRepository backed by Supabase GoTrue,
/// PostgreSQL database with RLS, and Supabase Storage.
/// Backed by GufiBackendStore when Supabase credentials are not provided.
///
/// SINGLETON: Use [SupabaseAuthRepository.instance] everywhere to ensure all
/// parts of the app (Riverpod providers, router guard, AuthPage) share one
/// _cachedProfile. Creating separate instances breaks profile state propagation.
class SupabaseAuthRepository implements AuthRepository {
  /// The single shared instance used throughout the app.
  static final SupabaseAuthRepository instance =
      SupabaseAuthRepository._internal();

  /// Private named constructor used for the singleton.
  SupabaseAuthRepository._internal()
    : _client = SupabaseConfig.isConfigured ? Supabase.instance.client : null {
    _initAuthListener();
  }

  final SupabaseClient? _client;
  final StreamController<UserProfile?> _authStateController =
      StreamController<UserProfile?>.broadcast();

  UserProfile? _cachedProfile;

  void _initAuthListener() {
    if (_client != null) {
      _client.auth.onAuthStateChange.listen((data) async {
        final session = data.session;
        if (session != null) {
          final profile = await _fetchProfile(session.user.id);
          _cachedProfile = profile;
          _authStateController.add(profile);
        } else {
          _cachedProfile = null;
          _authStateController.add(null);
        }
      });
    }
  }

  @override
  Stream<UserProfile?> get authStateChanges => _authStateController.stream;

  @override
  UserProfile? get currentUserProfile => _cachedProfile;

  @override
  Future<bool> emailExists(String email) async {
    final normalized = DisposableEmailService.normalizeEmail(email);

    if (_client != null) {
      try {
        final res = await _client
            .from('users')
            .select('id')
            .eq('email_normalized', normalized)
            .maybeSingle();
        return res != null;
      } catch (_) {
        return false;
      }
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      return GufiBackendStore.instance.emailExists(normalized);
    }
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final normalized = username.trim().toLowerCase().replaceFirst('@', '');
    if (normalized.length < 3 || normalized.length > 24) return false;
    if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(normalized)) return false;

    const reserved = {
      'admin',
      'administrator',
      'gufi',
      'support',
      'help',
      'official',
      'system',
      'moderator',
      'security',
      'root',
      'staff',
      'team',
    };
    if (reserved.contains(normalized)) return false;

    if (_client != null) {
      try {
        final available = await _client.rpc<bool>(
          'is_username_available',
          params: {'input_username': normalized},
        );
        return available;
      } catch (_) {
        // Fallback direct check
        final res = await _client
            .from('users')
            .select('id')
            .eq('username_normalized', normalized)
            .maybeSingle();
        return res == null;
      }
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      return !GufiBackendStore.instance.usernameExists(normalized);
    }
  }

  @override
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final normalized = DisposableEmailService.normalizeEmail(email);

    if (DisposableEmailService.isDisposable(normalized)) {
      throw const AuthException('Please use a permanent email address.');
    }

    if (password.length < 6) {
      throw const AuthException('Password must be at least 6 characters.');
    }

    if (_client != null) {
      final response = await _client.auth.signUp(
        email: normalized,
        password: password,
      );
      if (response.user == null) {
        throw const AuthException('Sign up failed. Please try again.');
      }
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      final tempProfile = UserProfile(
        id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
        email: normalized,
        emailNormalized: normalized,
        emailVerified: true,
        username: '',
        usernameNormalized: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      GufiBackendStore.instance.saveUser(tempProfile, password: password);
      _cachedProfile = tempProfile;
      _authStateController.add(tempProfile);
    }
  }

  @override
  Future<void> resendEmailVerification(String email) async {
    final normalized = DisposableEmailService.normalizeEmail(email);
    if (_client != null) {
      await _client.auth.resend(type: OtpType.signup, email: normalized);
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
  }

  @override
  Future<bool> checkEmailVerified() async {
    if (_client != null) {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      return user.emailConfirmedAt != null;
    } else {
      return _cachedProfile?.emailVerified ?? true;
    }
  }

  @override
  Future<UserProfile> completeUserProfile({
    required String username,
    String? displayName,
    String? photoFilePath,
  }) async {
    final cleanUsername = username.trim().replaceFirst('@', '');
    final normUsername = cleanUsername.toLowerCase();

    String? photoUrl;

    if (_client != null) {
      final user = _client.auth.currentUser;
      if (user == null) throw const AuthException('Not authenticated');

      if (photoFilePath != null && photoFilePath.isNotEmpty) {
        final file = File(photoFilePath);
        if (await file.exists()) {
          final fileExt = photoFilePath.split('.').last;
          final storagePath =
              '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
          await _client.storage
              .from('avatars')
              .upload(
                storagePath,
                file,
                fileOptions: const FileOptions(upsert: true),
              );
          photoUrl = _client.storage.from('avatars').getPublicUrl(storagePath);
        }
      }

      await _client.rpc(
        'complete_user_signup',
        params: {
          'p_username': cleanUsername,
          'p_display_name': displayName ?? cleanUsername,
          'p_photo_url': photoUrl,
        },
      );

      final updated = await _fetchProfile(user.id);
      _cachedProfile = updated;
      _authStateController.add(updated);
      return updated ??
          UserProfile(
            id: user.id,
            email: user.email ?? '',
            emailNormalized: DisposableEmailService.normalizeEmail(
              user.email ?? '',
            ),
            emailVerified: user.emailConfirmedAt != null,
            username: cleanUsername,
            usernameNormalized: normUsername,
            displayName: displayName ?? cleanUsername,
            profilePhotoUrl: photoUrl,
            onboardingCompleted: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      final current =
          _cachedProfile ??
          UserProfile(
            id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
            email: 'user@gufi.app',
            emailNormalized: 'user@gufi.app',
            emailVerified: true,
            username: cleanUsername,
            usernameNormalized: normUsername,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      final updated = current.copyWith(
        username: cleanUsername,
        usernameNormalized: normUsername,
        displayName: displayName ?? cleanUsername,
        profilePhotoUrl: photoFilePath,
        emailVerified: true,
        onboardingCompleted: true,
        updatedAt: DateTime.now(),
      );

      GufiBackendStore.instance.saveUser(updated);
      _cachedProfile = updated;
      _authStateController.add(updated);
      return updated;
    }
  }

  @override
  Future<UserProfile> logIn({
    required String email,
    required String password,
  }) async {
    final normalized = DisposableEmailService.normalizeEmail(email);

    if (_client != null) {
      final res = await _client.auth.signInWithPassword(
        email: normalized,
        password: password,
      );
      final user = res.user;
      if (user == null) throw const AuthException('Invalid login credentials');

      final profile = await _fetchProfile(user.id);
      if (profile == null) {
        throw const AuthException('User profile record not found.');
      }
      if (profile.isDisabled) {
        await _client.auth.signOut();
        throw const AuthException(
          'This account has been disabled. Contact support.',
        );
      }

      _cachedProfile = profile;
      _authStateController.add(profile);
      return profile;
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (password == 'incorrect') {
        throw const AuthException('Incorrect password. Try again.');
      }

      final isAdmin = normalized == 'admin@gufi.app';
      var profile = GufiBackendStore.instance.getUserByEmail(normalized);

      if (profile == null && isAdmin) {
        profile = UserProfile(
          id: 'admin-uid',
          email: normalized,
          emailNormalized: normalized,
          emailVerified: true,
          username: 'admin',
          usernameNormalized: 'admin',
          displayName: 'Gufi Administrator',
          role: 'admin',
          onboardingCompleted: true,
          accountStatus: 'active',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        GufiBackendStore.instance.saveUser(profile, password: password);
      }

      if (profile == null) {
        throw const AuthException('Invalid login credentials');
      }

      if (profile.isDisabled) {
        throw const AuthException(
          'This account has been disabled. Contact support.',
        );
      }

      _cachedProfile = profile;
      _authStateController.add(profile);
      return profile;
    }
  }

  @override
  Future<UserProfile> signInWithApple() async {
    if (_client != null) {
      await _client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'gufi://login-callback',
      );
      final user = _client.auth.currentUser;
      if (user != null) {
        final profile = await _fetchProfile(user.id);
        _cachedProfile = profile;
        _authStateController.add(profile);
        return profile!;
      }
      throw const AuthException('Apple authentication did not complete');
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final profile = UserProfile(
        id: 'apple-${DateTime.now().millisecondsSinceEpoch}',
        email: 'appleuser@privaterelay.appleid.com',
        emailNormalized: 'appleuser@privaterelay.appleid.com',
        emailVerified: true,
        username: 'appleuser',
        usernameNormalized: 'appleuser',
        authProvider: 'apple',
        onboardingCompleted: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      GufiBackendStore.instance.saveUser(profile);
      _cachedProfile = profile;
      _authStateController.add(profile);
      return profile;
    }
  }

  @override
  Future<UserProfile> signInWithGoogle() async {
    if (_client != null) {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'gufi://login-callback',
      );
      final user = _client.auth.currentUser;
      if (user != null) {
        final profile = await _fetchProfile(user.id);
        _cachedProfile = profile;
        _authStateController.add(profile);
        return profile!;
      }
      throw const AuthException('Google authentication did not complete');
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final profile = UserProfile(
        id: 'google-${DateTime.now().millisecondsSinceEpoch}',
        email: 'googleuser@gmail.com',
        emailNormalized: 'googleuser@gmail.com',
        emailVerified: true,
        username: 'googleuser',
        usernameNormalized: 'googleuser',
        authProvider: 'google',
        onboardingCompleted: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      GufiBackendStore.instance.saveUser(profile);
      _cachedProfile = profile;
      _authStateController.add(profile);
      return profile;
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    final normalized = DisposableEmailService.normalizeEmail(email);
    if (_client != null) {
      await _client.auth.resetPasswordForEmail(
        normalized,
        redirectTo: 'gufi://reset-callback',
      );
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  @override
  Future<void> signOut() async {
    if (_client != null) {
      await _client.auth.signOut();
    }
    _cachedProfile = null;
    _authStateController.add(null);
  }

  @override
  Future<UserProfile?> restoreSession() async {
    if (_client != null) {
      final session = _client.auth.currentSession;
      if (session != null) {
        final profile = await _fetchProfile(session.user.id);
        _cachedProfile = profile;
        _authStateController.add(profile);
        return profile;
      }
    }
    return _cachedProfile;
  }

  @override
  Future<UserProfile?> fetchCurrentProfile() async {
    // Return cached value immediately if available.
    if (_cachedProfile != null) return _cachedProfile;

    if (_client != null) {
      final user = _client.auth.currentUser;
      if (user == null) return null;
      final profile = await _fetchProfile(user.id);
      if (profile != null) {
        _cachedProfile = profile;
        _authStateController.add(profile);
      }
      return profile;
    } else {
      // No Supabase: return cached profile from GufiBackendStore if available.
      return _cachedProfile;
    }
  }

  Future<UserProfile?> _fetchProfile(String userId) async {
    if (_client == null) return null;
    try {
      final data = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data != null) {
        return UserProfile.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
    return null;
  }
}
