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

  /// E-mail kontaktu / obsługi sklepu (UI „Pomoc”, stopka).
  static const String shopSupportEmail = String.fromEnvironment(
    'SHOP_SUPPORT_EMAIL',
    defaultValue: 'kontakt@sellektywni.pl',
  );

  static const bool _devMockFromDefine = bool.fromEnvironment(
    'USE_DEV_MOCK_AUTH',
    defaultValue: false,
  );

  /// Logowanie dev-mock (bez Supabase): profil i rola z dummy danych w aplikacji;
  /// opcjonalnie backend z `AUTH_DEV_MOCK=true` gdy API jest uruchomione.
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

  /// Tylko **localhost / 127.0.0.1**: wymusza sesję dev-mock z daną rolą (bez logowania).
  /// Przykład: `.../app/?previewAs=OWNER` albo `?previewAs=STAFF`, `?previewAs=CUSTOMER`.
  /// Na produkcji ignorowane (inny host).
  static String? get previewAsRole {
    if (!kIsWeb) return null;
    final host = Uri.base.host;
    if (host != 'localhost' && host != '127.0.0.1') return null;
    final raw = Uri.base.queryParameters['previewAs']?.trim().toUpperCase();
    if (raw == null || raw.isEmpty) return null;
    if (raw == 'OWNER' || raw == 'STAFF' || raw == 'CUSTOMER') return raw;
    return null;
  }
}
