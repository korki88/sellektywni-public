import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../config/shop_market_holder.dart';
import 'auth_storage.dart';
import '../config/dev_mock_accounts.dart';

/// Sesja: token API (Supabase JWT), profil RBAC z Nest `/auth/me`.
class AuthSession extends ChangeNotifier {
  static const String _apiBaseFromDefine = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Domyślny URL API: z `--dart-define`, albo ten sam host co strona WWW + port 3000 (localhost vs 127.0.0.1).
  static String get defaultApiBase {
    var d = _apiBaseFromDefine.trim();
    if (d.isNotEmpty) {
      return d.endsWith('/') ? d.substring(0, d.length - 1) : d;
    }
    if (kIsWeb) {
      final h = Uri.base.host;
      if (h == 'localhost' || h == '127.0.0.1') {
        return 'http://$h:3000';
      }
    }
    return 'http://localhost:3000';
  }

  String? _accessToken;
  String? _role;
  String? _profileEmail;
  int? _points;
  String? _rank;
  List<String> _permissions = const [];
  String _apiBase = defaultApiBase;
  bool _ready = false;

  bool get isReady => _ready;
  String? get accessToken => _accessToken;
  String? get role => _role;
  String? get profileEmail => _profileEmail;
  int? get points => _points;
  String? get rank => _rank;
  List<String> get permissions => List.unmodifiable(_permissions);
  String get apiBase => _apiBase;
  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;

  bool get isAuthenticated => hasToken;

  bool get isStaff => _role == 'STAFF';
  bool get isOwner => _role == 'OWNER';
  bool get isCustomer => _role == 'CUSTOMER';

  /// Panel AdminDashboard (OWNER pełny, STAFF operacje sklepowe).
  bool get isAdminDashboardRole => isStaff || isOwner;
  bool hasPermission(String key) => isOwner || _permissions.contains(key);

  /// DevMode: token `dev-mock:*` — profil tylko lokalnie (bez Nest / Postgres).
  bool _applyDevMockProfileIfNeeded() {
    final fields = devMockProfileFieldsForToken(_accessToken);
    if (fields == null) return false;
    _role = fields.role;
    _profileEmail = fields.email;
    _points = fields.points;
    _rank = fields.rank;
    _permissions = switch (fields.role) {
      'OWNER' => const [
          'manage.reservations',
          'manage.customers',
          'manage.orders',
          'manage.dotykacka',
          'manage.permissions',
          'view.analytics',
        ],
      'STAFF' => const [
          'manage.reservations',
          'manage.customers',
          'manage.orders',
          'manage.dotykacka',
        ],
      _ => const [],
    };
    return true;
  }

  Future<void> init() async {
    try {
      _accessToken = await authStorageGetToken();
      var base = await authStorageGetApiBase() ?? defaultApiBase;
      if (kIsWeb) {
        final pageHost = Uri.base.host;
        if (pageHost == '127.0.0.1' &&
            base.contains('localhost') &&
            base.contains(':3000')) {
          base = 'http://127.0.0.1:3000';
          await authStorageSetApiBase(base);
        }
      }
      _apiBase = base;
    } catch (_) {
      _apiBase = AuthSession.defaultApiBase;
    }
    unawaited(ShopMarketHolder.refresh(_apiBase));
    _applyPreviewRoleFromUrlIfAny();
    _ready = true;
    notifyListeners();
    if (hasToken) {
      unawaited(refreshProfile());
    }
  }

  /// Localhost: `?previewAs=OWNER|STAFF|CUSTOMER` — podgląd UI bez formularza logowania.
  void _applyPreviewRoleFromUrlIfAny() {
    final role = AppConfig.previewAsRole;
    if (role == null) return;
    final token = devMockTokenForPreviewRole(role);
    if (token == null) return;
    _accessToken = token;
    _applyDevMockProfileIfNeeded();
    unawaited(_persistTokenForPreview(token));
  }

  Future<void> _persistTokenForPreview(String token) async {
    try {
      await authStorageSetToken(token);
    } catch (_) {}
  }

  Future<void> setApiBase(String value) async {
    final v = value.trim();
    if (v.isEmpty) return;
    _apiBase = v.endsWith('/') ? v.substring(0, v.length - 1) : v;
    await authStorageSetApiBase(_apiBase);
    unawaited(ShopMarketHolder.refresh(_apiBase));
    notifyListeners();
  }

  Future<void> setAccessToken(String? token) async {
    final t = token?.trim();
    _accessToken = (t == null || t.isEmpty) ? null : t;
    if (_accessToken == null) {
      await authStorageSetToken(null);
      _role = null;
      _profileEmail = null;
      _points = null;
      _rank = null;
      _permissions = const [];
    } else {
      await authStorageSetToken(_accessToken!);
      // Jak przy Supabase: najpierw ensure profilu w Postgres, potem /auth/me (rola, punkty).
      await afterSignIn();
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
    await authStorageSetToken(_accessToken!);
    notifyListeners();
    await afterSignIn();
  }

  /// Po zalogowaniu: profil w Postgres + pełne `/auth/me` (albo dummy przy `dev-mock:*`).
  Future<void> afterSignIn() async {
    if (!hasToken) return;
    if (_applyDevMockProfileIfNeeded()) {
      notifyListeners();
      return;
    }
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
    if (_applyDevMockProfileIfNeeded()) {
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
        _permissions = const [];
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
        _permissions = const [];
      } else {
        _role = prof['role'] as String?;
        _profileEmail = prof['email'] as String?;
        _points = (prof['points'] as num?)?.toInt();
        _rank = prof['rank'] as String?;
        final permsRaw = prof['permissions'];
        if (permsRaw is List) {
          _permissions = permsRaw.whereType<String>().toList();
        } else {
          _permissions = const [];
        }
      }
    } catch (_) {
      _role = null;
      _profileEmail = null;
      _points = null;
      _rank = null;
      _permissions = const [];
    }
    notifyListeners();
  }
}
