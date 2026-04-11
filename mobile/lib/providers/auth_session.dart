import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Sesja użytkownika: token Supabase, rola RBAC z GET /auth/me, URL API.
class AuthSession extends ChangeNotifier {
  static const String defaultApiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const _kToken = 'auth_access_token';
  static const _kApiBase = 'auth_api_base';

  String? _accessToken;
  String? _role;
  String _apiBase = defaultApiBase;
  bool _ready = false;

  bool get isReady => _ready;
  String? get accessToken => _accessToken;
  String? get role => _role;
  String get apiBase => _apiBase;
  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;

  /// Tylko rola STAFF uruchamia panel (main_sidebar); OWNER/ CUSTOMER / null → sklep.
  bool get isStaff => _role == 'STAFF';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kToken);
    _apiBase = prefs.getString(_kApiBase) ?? defaultApiBase;
    if (hasToken) {
      await refreshProfile();
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> setApiBase(String value) async {
    final v = value.trim();
    if (v.isEmpty) return;
    _apiBase = v.endsWith('/') ? v.substring(0, v.length - 1) : v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiBase, _apiBase);
    notifyListeners();
  }

  Future<void> setAccessToken(String? token) async {
    final t = token?.trim();
    _accessToken = (t == null || t.isEmpty) ? null : t;
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken == null) {
      await prefs.remove(_kToken);
      _role = null;
    } else {
      await prefs.setString(_kToken, _accessToken!);
      await refreshProfile();
    }
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    if (!hasToken) {
      _role = null;
      notifyListeners();
      return;
    }
    try {
      final uri = Uri.parse('$_apiBase/auth/me');
      final r = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $_accessToken'},
      );
      if (r.statusCode != 200) {
        _role = null;
        notifyListeners();
        return;
      }
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final prof = j['profile'];
      if (prof == null) {
        _role = null;
      } else {
        _role = prof['role'] as String?;
      }
    } catch (_) {
      _role = null;
    }
    notifyListeners();
  }
}
