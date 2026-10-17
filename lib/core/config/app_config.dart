/// Global application configuration
class AppConfig {
  /// Base URL for web invite links (empty or null in dev until genuine domain is configured)
  static const String inviteBaseUrl = String.fromEnvironment(
    'GUFI_INVITE_BASE_URL',
    defaultValue: '',
  );

  /// Scheme for app deep-linking
  static const String appScheme = 'gufi';

  /// Whether a genuine HTTPS invite domain is configured
  static bool get hasConfiguredWebDomain =>
      inviteBaseUrl.isNotEmpty &&
      inviteBaseUrl.startsWith('https://') &&
      !inviteBaseUrl.contains('gufi.app');

  /// Build canonical deep link or web link for an invite code
  static String buildInviteLink(String canonicalCode) {
    if (hasConfiguredWebDomain) {
      final base = inviteBaseUrl.endsWith('/')
          ? inviteBaseUrl.substring(0, inviteBaseUrl.length - 1)
          : inviteBaseUrl;
      return '$base/join/$canonicalCode';
    }
    // Fallback guaranteed to work with native app scheme
    return '$appScheme://join?code=$canonicalCode';
  }

  /// Build standard share text for sharing a circle invite
  static String buildShareText({
    required String circleName,
    required String code,
  }) {
    final link = buildInviteLink(code);
    return 'Join my Circle “$circleName” on Gufi.\n\nInvite code: $code\n\nOpen in Gufi:\n$link';
  }
}
