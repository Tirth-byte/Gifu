import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';
import 'core/services/app_preferences_service.dart';
import 'core/services/gufi_backend_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local persistent storage & preferences
  await AppPreferencesService.instance.init();
  await GufiBackendStore.instance.init();

  // Initialize Supabase backend
  if (kReleaseMode) {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(
        'Missing SUPABASE_URL or SUPABASE_ANON_KEY in Release mode. '
        'Provide them via --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // ignore: deprecated_member_use
      anonKey: SupabaseConfig.anonKey,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: true),
    );
  } else if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        // ignore: deprecated_member_use
        anonKey: SupabaseConfig.anonKey,
        authOptions: const FlutterAuthClientOptions(detectSessionInUri: true),
      );
    } catch (e) {
      debugPrint('Supabase initialization failed in debug: $e');
    }
  }

  // Set immersive dark status and navigation bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: App()));
}
