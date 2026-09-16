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
  Future<UserProfile?> fetchCurrentProfile();
}
