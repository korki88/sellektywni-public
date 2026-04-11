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

  /// Logowanie fikcyjne admin/user/client bez Supabase (wymaga API z AUTH_DEV_MOCK).
  static const bool useDevMockAuth = bool.fromEnvironment(
    'USE_DEV_MOCK_AUTH',
    defaultValue: false,
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Supabase Flutter — wyłączony przy mocku (inaczej brak init → błąd).
  static bool get shouldUseSupabaseClient => hasSupabase && !useDevMockAuth;
}
