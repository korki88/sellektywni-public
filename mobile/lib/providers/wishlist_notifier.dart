import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_session.dart';

/// Ulubione produkty zsynchronizowane z API (`GET /order/wishlist`).
class WishlistNotifier extends ChangeNotifier {
  AuthSession? _auth;
  final List<Map<String, dynamic>> _rows = [];
  bool _loading = false;

  List<Map<String, dynamic>> get rows => List.unmodifiable(_rows);
  bool get loading => _loading;

  bool contains(String productId) =>
      _rows.any((e) => e['productId']?.toString() == productId);

  void bindAuth(AuthSession auth) {
    _auth = auth;
    if (auth.isAuthenticated) {
      load();
    } else {
      _rows.clear();
      notifyListeners();
    }
  }

  Future<void> load() async {
    final auth = _auth;
    final token = auth?.accessToken;
    if (auth == null || !auth.isAuthenticated || token == null || token.isEmpty) {
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      final uri = Uri.parse('${auth.apiBase}/order/wishlist');
      final r = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) {
        _loading = false;
        notifyListeners();
        return;
      }
      final j = jsonDecode(r.body);
      if (j is! List) {
        _loading = false;
        notifyListeners();
        return;
      }
      _rows
        ..clear()
        ..addAll(j.whereType<Map<String, dynamic>>());
    } catch (_) {
      // sieć — zostaw poprzedni stan
    }
    _loading = false;
    notifyListeners();
  }

  Future<String?> toggle(String productId) async {
    final auth = _auth;
    final token = auth?.accessToken;
    if (auth == null || !auth.isAuthenticated || token == null || token.isEmpty) {
      return 'Zaloguj się, aby dodać produkt do ulubionych.';
    }
    final remove = contains(productId);
    try {
      if (remove) {
        final uri = Uri.parse('${auth.apiBase}/order/wishlist/$productId');
        final r = await http
            .delete(uri, headers: {'Authorization': 'Bearer $token'})
            .timeout(const Duration(seconds: 12));
        if (r.statusCode != 200 && r.statusCode != 204) {
          return 'Nie udało się usunąć z ulubionych.';
        }
        _rows.removeWhere((e) => e['productId']?.toString() == productId);
      } else {
        final uri = Uri.parse('${auth.apiBase}/order/wishlist');
        final r = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode({'productId': productId}),
            )
            .timeout(const Duration(seconds: 12));
        if (r.statusCode != 200 && r.statusCode != 201) {
          return 'Nie udało się dodać do ulubionych.';
        }
        await load();
        return null;
      }
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
