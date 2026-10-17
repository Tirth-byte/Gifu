/// Authenticated user profile entity.
class UserProfile {
  final String id;
  final String email;
  final String emailNormalized;
  final bool emailVerified;
  final String username;
  final String usernameNormalized;
  final String? displayName;
  final String? profilePhotoUrl;
  final String? bio;
  final String? timezone;
  final String authProvider;
  final String role; // 'user' | 'admin'
  final bool onboardingCompleted;
  final bool profileComplete;
  final String accountStatus; // 'active' | 'disabled'
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.emailNormalized,
    required this.emailVerified,
    required this.username,
    required this.usernameNormalized,
    this.displayName,
    this.profilePhotoUrl,
    this.bio,
    this.timezone,
    this.authProvider = 'email',
    this.role = 'user',
    this.onboardingCompleted = false,
    bool? profileComplete,
    this.accountStatus = 'active',
    required this.createdAt,
    required this.updatedAt,
  }) : profileComplete = profileComplete ?? onboardingCompleted;

  bool get isAdmin => role == 'admin';
  bool get isActive => accountStatus == 'active';
  bool get isDisabled => accountStatus == 'disabled';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final email = json['email'] as String? ?? '';
    final username = json['username'] as String? ?? '';
    final isComplete =
        (json['profile_complete'] as bool?) ??
        (json['onboarding_completed'] as bool?) ??
        (username.isNotEmpty);

    return UserProfile(
      id: json['id'] as String? ?? '',
      email: email,
      emailNormalized:
          (json['email_normalized'] as String?) ?? email.toLowerCase(),
      emailVerified: json['email_verified'] as bool? ?? true,
      username: username,
      usernameNormalized:
          (json['username_normalized'] as String?) ?? username.toLowerCase(),
      displayName: json['display_name'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      bio: json['bio'] as String?,
      timezone: json['timezone'] as String?,
      authProvider: json['auth_provider'] as String? ?? 'email',
      role: json['role'] as String? ?? 'user',
      onboardingCompleted: isComplete,
      profileComplete: isComplete,
      accountStatus: json['account_status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'email_normalized': emailNormalized,
      'email_verified': emailVerified,
      'username': username,
      'username_normalized': usernameNormalized,
      'display_name': displayName,
      'profile_photo_url': profilePhotoUrl,
      'bio': bio,
      'timezone': timezone,
      'auth_provider': authProvider,
      'role': role,
      'profile_complete': profileComplete,
      'onboarding_completed': onboardingCompleted,
      'account_status': accountStatus,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? emailNormalized,
    bool? emailVerified,
    String? username,
    String? usernameNormalized,
    String? displayName,
    String? profilePhotoUrl,
    String? bio,
    String? timezone,
    String? authProvider,
    String? role,
    bool? onboardingCompleted,
    bool? profileComplete,
    String? accountStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final complete =
        profileComplete ?? onboardingCompleted ?? this.profileComplete;
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      emailNormalized: emailNormalized ?? this.emailNormalized,
      emailVerified: emailVerified ?? this.emailVerified,
      username: username ?? this.username,
      usernameNormalized: usernameNormalized ?? this.usernameNormalized,
      displayName: displayName ?? this.displayName,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      bio: bio ?? this.bio,
      timezone: timezone ?? this.timezone,
      authProvider: authProvider ?? this.authProvider,
      role: role ?? this.role,
      onboardingCompleted: complete,
      profileComplete: complete,
      accountStatus: accountStatus ?? this.accountStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
