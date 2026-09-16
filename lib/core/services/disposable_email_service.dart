/// Service to detect and reject disposable or temporary email domains.
/// Protects against disposable inboxes while preserving legitimate domains,
/// custom company domains, universities, and Apple Private Relay.
class DisposableEmailService {
  /// Known temporary / throwaway / disposable email domains.
  static final Set<String> _disposableDomains = {
    // Mailinator & family
    'mailinator.com',
    'mailinator.net',
    'mailinator2.com',
    'suremail.info',
    'spamherelots.com',
    'sharklasers.com',
    'guerrillamail.com',
    'guerrillamail.block',
    'guerrillamail.net',
    'guerrillamail.org',
    'guerrillamail.biz',
    'guerrillamailblock.com',
    'grr.la',

    // 10 minute mail & temp mail
    '10minutemail.com',
    '10minutemail.net',
    '10minutemail.org',
    '10minutemail.co.uk',
    'tempmail.com',
    'temp-mail.org',
    'temp-mail.io',
    'tempail.com',
    'fakemailgenerator.com',
    'generator.email',
    'throwawaymail.com',
    'dispostable.com',
    'yopmail.com',
    'yopmail.fr',
    'yopmail.net',
    'cool.fr.nf',
    'jetable.fr.nf',
    'trashmail.com',
    'trashmail.net',
    'trashmail.me',
    'getairmail.com',
    'mohmal.com',
    'crazymailing.com',
    'mailcatch.com',
    'maildrop.cc',
    'nada.ltd',
    'getnada.com',
    'inboxkitten.com',
    'burnermail.io',
    'mytemp.email',
    'tempinbox.com',
    'mailnesia.com',
    'minutemailbox.com',
    'emailondeck.com',
    'tempmailaddress.com',
    'tmailor.com',
    'internxt.com/temporary-email',
    'dropmail.me',
    'fastmail.org',
    'spamfree24.org',
    'discard.email',
    'disposablemail.com',
    'mytempmail.com',
    'fakeinbox.com',
    'anonaddy.me',
    'mytrashmail.com',
    'boun.cr',
    'trashinbox.com',
  };

  /// Checks basic RFC email syntax validity.
  static bool isValidSyntax(String email) {
    final regex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
    );
    return regex.hasMatch(email.trim());
  }

  /// Normalizes an email address safely:
  /// trims surrounding whitespace, lowercases the domain portion,
  /// and preserves standard mailbox formatting.
  static String normalizeEmail(String email) {
    final trimmed = email.trim();
    final atIndex = trimmed.lastIndexOf('@');
    if (atIndex == -1 || atIndex == trimmed.length - 1) {
      return trimmed.toLowerCase();
    }
    final mailbox = trimmed.substring(0, atIndex).trim();
    final domain = trimmed.substring(atIndex + 1).trim().toLowerCase();
    return '$mailbox@$domain';
  }

  /// Extracts the domain portion of an email.
  static String extractDomain(String email) {
    final normalized = normalizeEmail(email);
    final parts = normalized.split('@');
    return parts.length == 2 ? parts[1] : '';
  }

  /// Returns true if the email domain is a recognized disposable provider.
  /// Explicitly allows Apple Private Relay (`privaterelay.appleid.com`).
  static bool isDisposable(String email) {
    final domain = extractDomain(email);
    if (domain.isEmpty) return false;

    // Apple Private Relay is a legitimate security feature
    if (domain == 'privaterelay.appleid.com') {
      return false;
    }

    if (_disposableDomains.contains(domain)) {
      return true;
    }

    // Check parent domains for wildcards
    final segments = domain.split('.');
    if (segments.length > 2) {
      final parentDomain = segments.sublist(segments.length - 2).join('.');
      if (_disposableDomains.contains(parentDomain)) {
        return true;
      }
    }

    return false;
  }
}
