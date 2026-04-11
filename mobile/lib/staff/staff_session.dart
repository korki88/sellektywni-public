import 'package:flutter/foundation.dart';

/// Sesja panelu pracownika: Bearer token (JWT Supabase) + bazowy URL API.
class StaffSession extends ChangeNotifier {
  StaffSession();

  static const String defaultApiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  String _apiBase = defaultApiBase;
  String? _accessToken;

  String get apiBase => _apiBase;
  String? get accessToken => _accessToken;
  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;

  void setApiBase(String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    _apiBase = v.endsWith('/') ? v.substring(0, v.length - 1) : v;
    notifyListeners();
  }

  void setAccessToken(String? token) {
    final t = token?.trim();
    _accessToken = (t == null || t.isEmpty) ? null : t;
    notifyListeners();
  }
}
