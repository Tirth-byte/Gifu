/// Service to export safe user records into RFC-4180 compliant CSV format
/// compatible with Microsoft Excel, Apple Numbers, and Google Sheets.
class CsvExportService {
  /// Converts rows of map entries into a sanitized CSV string with UTF-8 BOM.
  static String generateUsersCsv(List<Map<String, dynamic>> userRecords) {
    final buffer = StringBuffer();

    // UTF-8 BOM for Microsoft Excel compatibility
    buffer.write('\uFEFF');

    final headers = [
      'User ID',
      'Email',
      'Email Verified',
      'Username',
      'Display Name',
      'Auth Provider',
      'Profile Photo Present',
      'Onboarding Completed',
      'Account Status',
      'Role',
      'Created At (UTC)',
      'Updated At (UTC)',
    ];

    buffer.writeln(headers.map(_escape).join(','));

    for (final user in userRecords) {
      final row = [
        user['id'] ?? '',
        user['email'] ?? '',
        user['email_verified'] == true ? 'YES' : 'NO',
        user['username'] ?? '',
        user['display_name'] ?? '',
        user['auth_provider'] ?? 'email',
        (user['profile_photo_url'] != null &&
                user['profile_photo_url'].toString().isNotEmpty)
            ? 'YES'
            : 'NO',
        user['onboarding_completed'] == true ? 'YES' : 'NO',
        user['account_status'] ?? 'active',
        user['role'] ?? 'user',
        user['created_at'] ?? '',
        user['updated_at'] ?? '',
      ];

      buffer.writeln(row.map(_escape).join(','));
    }

    return buffer.toString();
  }

  /// RFC-4180 escaping: wrap in double quotes if string contains comma, quote, or newline.
  static String _escape(dynamic value) {
    if (value == null) return '""';
    final str = value.toString();
    if (str.contains(',') ||
        str.contains('"') ||
        str.contains('\n') ||
        str.contains('\r')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return '"$str"';
  }
}
