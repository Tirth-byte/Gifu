/// Configuration for Supabase Backend.
/// Values can be supplied via `--dart-define` at build/run time,
/// e.g. `--dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=abc`
class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://preview-instance.gufi.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.preview_anon_key',
  );

  /// True if valid non-placeholder credentials have been provided.
  static bool get isConfigured {
    return url.isNotEmpty &&
        !url.contains('preview-instance') &&
        anonKey.isNotEmpty &&
        !anonKey.contains('preview_anon_key');
  }
}
