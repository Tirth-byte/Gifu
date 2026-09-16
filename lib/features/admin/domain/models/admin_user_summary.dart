import '../../../auth/domain/models/user_profile.dart';

/// Single source of truth: AdminUserSummary is an alias for the canonical UserProfile.
/// Ensures that Auth, Coming Soon, and Admin share the exact same domain entity.
typedef AdminUserSummary = UserProfile;
