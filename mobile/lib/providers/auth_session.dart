import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Sesja: token API (Supabase JWT), profil RBAC z Nest `/auth/me`.
class AuthSession extends ChangeNotifier {
  static const String defaultApiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  static const _kToken = 'auth_access_token';
  static const _kApiBase = 'auth_api_base';

  String? _accessToken;
  String? _role;
  String? _profileEmail;
  int? _points;
  String? _rank;
  String _apiBase = defaultApiBase;
  bool _ready = false;

  bool get isReady => _ready;
  String? get accessToken => _accessToken;
  String? get role => _role;
  String? get profileEmail => _profileEmail;
  int? get points => _points;
  String? get rank => _rank;
  String get apiBase => _apiBase;
  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;

  bool get isAuthenticated => hasToken;

  bool get isStaff => _role == 'STAFF';
  bool get isOwner => _role == 'OWNER';
  bool get isCustomer => _role == 'CUSTOMER';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString(_kToken);
      _apiBase = prefs.getString(_kApiBase) ?? defaultApiBase;
    } catch (_) {
      _apiBase = defaultApiBase;
    }
    _ready = true;
    notifyListeners();
    if (hasToken) {
      unawaited(refreshProfile());
    }
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
      _profileEmail = null;
      _points = null;
      _rank = null;
    } else {
      await prefs.setString(_kToken, _accessToken!);
      await refreshProfile();
    }
    notifyListeners();
  }

  /// Synchronizacja z sesją Supabase (logowanie / wylogowanie / odświeżenie tokenu).
  Future<void> syncFromSupabaseAccessToken(String? token) async {
    final t = token?.trim();
    if (t == null || t.isEmpty) {
      await setAccessToken(null);
      return;
    }
    _accessToken = t;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, _accessToken!);
    notifyListeners();
    await afterSignIn();
  }

  /// Po zalogowaniu: profil w Postgres + pełne `/auth/me`.
  Future<void> afterSignIn() async {
    if (!hasToken) return;
    try {
      final uri = Uri.parse('$_apiBase/auth/profile/ensure');
      await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $_accessToken',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {}
    await refreshProfile();
  }

  Future<void> refreshProfile() async {
    if (!hasToken) {
      _role = null;
      _profileEmail = null;
      _points = null;
      _rank = null;
      notifyListeners();
      return;
    }
    try {
      final uri = Uri.parse('$_apiBase/auth/me');
      final r = await http
          .get(
            uri,
            headers: {'Authorization': 'Bearer $_accessToken'},
          )
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) {
        _role = null;
        _profileEmail = null;
        _points = null;
        _rank = null;
        notifyListeners();
        return;
      }
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final prof = j['profile'];
      if (prof == null || prof is! Map<String, dynamic>) {
        _role = null;
        _profileEmail = null;
        _points = null;
        _rank = null;
      } else {
        _role = prof['role'] as String?;
        _profileEmail = prof['email'] as String?;
        _points = (prof['points'] as num?)?.toInt();
        _rank = prof['rank'] as String?;
      }
    } catch (_) {
      _role = null;
      _profileEmail = null;
      _points = null;
      _rank = null;
    }
    notifyListeners();
  }
}
