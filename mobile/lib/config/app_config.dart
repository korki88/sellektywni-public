import 'package:flutter/foundation.dart';

/// Konfiguracja z `--dart-define` przy buildzie / uruchomieniu.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static const bool _devMockFromDefine = bool.fromEnvironment(
    'USE_DEV_MOCK_AUTH',
    defaultValue: false,
  );

  /// Logowanie dev-mock (bez Supabase): wymaga API z `AUTH_DEV_MOCK=true`.
  ///
  /// Włączone gdy: `--dart-define=USE_DEV_MOCK_AUTH=true`, albo na **localhost / 127.0.0.1**
  /// w przeglądarce przy buildzie **bez** SUPABASE_URL+ANON_KEY (typowy podgląd z `www`).
  /// Przy zbudowanym Supabase: dopisz `?devMock=1` w URL.
  static bool get useDevMockAuth {
    if (_devMockFromDefine) return true;
    if (!kIsWeb) return false;
    final host = Uri.base.host;
    final local = host == 'localhost' || host == '127.0.0.1';
    if (!local) return false;
    if (!hasSupabase) return true;
    final q = Uri.base.queryParameters['devMock'];
    return q == '1' || q == 'true';
  }

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Supabase Flutter — wyłączony przy mocku (inaczej brak init → błąd).
  static bool get shouldUseSupabaseClient => hasSupabase && !useDevMockAuth;
}
