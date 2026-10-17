import '../models/user_profile.dart';

/// Contract for Authentication and Profile Management.
abstract class AuthRepository {
  /// Stream of user profile changes when session or profile updates.
  Stream<UserProfile?> get authStateChanges;

  /// Current in-memory cached user profile.
  UserProfile? get currentUserProfile;

  /// Checks if an email is already registered.
  Future<bool> emailExists(String email);

  /// Checks if a username is available (case-insensitive and not reserved).
  Future<bool> isUsernameAvailable(String username);

  /// Registers a new user with email and password and triggers verification.
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Resends email verification with rate-limiting support.
  Future<void> resendEmailVerification(String email);

  /// Checks if the current authenticated user has verified their email address.
  Future<bool> checkEmailVerified();

  /// Checks email verification status comprehensively:
  /// - Case A: Session exists and email is confirmed -> confirmedWithSession
  /// - Case B: No active session on mobile -> needsSignIn ("Email verified. Sign in to continue.")
  /// - Case C: Session exists but email unconfirmed -> unconfirmed ("Email not yet verified.")
  Future<VerificationCheckResult> checkEmailVerificationStatus();

  /// Completes profile setup atomically: claims username and uploads photo if provided.
  Future<UserProfile> completeUserProfile({
    required String username,
    String? displayName,
    String? photoFilePath,
  });

  /// Logs in with email and password, returning the user profile and role.
  Future<UserProfile> logIn({required String email, required String password});

  /// Sign in with Apple on iOS devices.
  Future<UserProfile> signInWithApple();

  /// Sign in with Google on iOS devices.
  Future<UserProfile> signInWithGoogle();

  /// Sends a secure password reset email.
  Future<void> sendPasswordReset(String email);

  /// Signs out of the current session.
  Future<void> signOut();

  /// Restores session on app startup and fetches latest profile.
  Future<UserProfile?> restoreSession();

  /// Fetches the current authenticated user's profile from the backend.
  /// Used for explicit reload and retry scenarios.
  Future<UserProfile?> fetchCurrentProfile({bool forceRefresh = false});
}

enum VerificationCheckStatus { confirmedWithSession, needsSignIn, unconfirmed }

class VerificationCheckResult {
  final VerificationCheckStatus status;
  final UserProfile? profile;
  final String? message;

  const VerificationCheckResult({
    required this.status,
    this.profile,
    this.message,
  });
}

class AvatarUploadException implements Exception {
  final String message;
  const AvatarUploadException([
    this.message = "Couldn't upload your photo. Try again.",
  ]);
  @override
  String toString() => message;
}

class ProfileUpdateException implements Exception {
  final String message;
  const ProfileUpdateException([
    this.message = "Couldn't finish your profile. Try again.",
  ]);
  @override
  String toString() => message;
}

class AuthFlowException implements Exception {
  final String message;
  const AuthFlowException(this.message);
  @override
  String toString() => message;
}
