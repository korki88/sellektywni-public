import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/product.dart';
import '../models/product_category.dart';
import 'auth_session.dart';
import 'cart_storage.dart';
import '../config/dev_mock_accounts.dart';

class CartNotifier extends ChangeNotifier {
  static const _guestOwnerKey = '__guest__';
  final Map<String, _CartState> _cartsByOwner = {};

  AuthSession? _auth;
  String _activeOwnerKey = _guestOwnerKey;
  bool _restored = false;

  CartNotifier() {
    unawaited(_restoreFromStorage());
  }

  int get itemCount => _activeCart.qtyById.values.fold(0, (a, b) => a + b);
  String get ownerKey => _activeOwnerKey;

  double get subtotalPln {
    var sum = 0.0;
    for (final e in _activeCart.qtyById.entries) {
      final p = _activeCart.products[e.key];
      if (p != null) {
        sum += p.pricePln * e.value;
      }
    }
    return sum;
  }

  List<({Product product, int qty})> get lines {
    return _activeCart.qtyById.entries
        .map((e) {
          final p = _activeCart.products[e.key];
          if (p == null) return null;
          return (product: p, qty: e.value);
        })
        .whereType<({Product product, int qty})>()
        .toList();
  }

  bool contains(Product product) => (_activeCart.qtyById[product.id] ?? 0) > 0;

  bool get canSyncServer => _auth?.isAuthenticated == true;

  void bindAuth(AuthSession auth) {
    if (!identical(_auth, auth)) {
      _auth?.removeListener(_onAuthChanged);
      _auth = auth;
      _auth?.addListener(_onAuthChanged);
    }
    // Wymuszamy synchronizację także gdy obiekt AuthSession jest ten sam,
    // bo ProxyProvider aktualizuje się przy każdym notify z auth.
    _switchOwner(forceNotify: true);
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  void add(Product product, {int qty = 1}) {
    _activeCart.products[product.id] = product;
    _activeCart.qtyById[product.id] = (_activeCart.qtyById[product.id] ?? 0) + qty;
    notifyListeners();
    unawaited(_persistToStorage());
  }

  void removeLine(String productId) {
    _activeCart.qtyById.remove(productId);
    _activeCart.products.remove(productId);
    notifyListeners();
    unawaited(_persistToStorage());
  }

  void decrement(String productId) {
    final q = _activeCart.qtyById[productId] ?? 0;
    if (q <= 1) {
      removeLine(productId);
      return;
    }
    _activeCart.qtyById[productId] = q - 1;
    notifyListeners();
    unawaited(_persistToStorage());
  }

  void clear() {
    _activeCart.qtyById.clear();
    _activeCart.products.clear();
    notifyListeners();
    unawaited(_persistToStorage());
  }

  _CartState get _activeCart =>
      _cartsByOwner.putIfAbsent(_activeOwnerKey, _CartState.new);

  void _onAuthChanged() {
    _switchOwner();
  }

  void _switchOwner({bool forceNotify = false}) {
    final previousOwner = _activeOwnerKey;
    final nextOwner = _ownerKeyForAuth();
    if (previousOwner == nextOwner && !forceNotify) return;

    // Logowanie: koszyk gościa przechodzi na właśnie zalogowanego użytkownika.
    if (previousOwner == _guestOwnerKey && nextOwner != _guestOwnerKey) {
      _assignGuestCartTo(nextOwner);
    }
    // Wylogowanie: koszyk gościa ma być pusty, aby nie „przeciekał” na kolejne logowania.
    if (previousOwner != _guestOwnerKey && nextOwner == _guestOwnerKey) {
      _clearGuestCart();
    }

    _activeOwnerKey = nextOwner;
    notifyListeners();
    unawaited(_persistToStorage());
  }

  String _ownerKeyForAuth() {
    final auth = _auth;
    if (auth == null || !auth.isAuthenticated) {
      return _guestOwnerKey;
    }
    final devRole = devMockRoleFromBearerToken(auth.accessToken);
    if (devRole != null && devRole.isNotEmpty) {
      return 'dev:${devRole.toUpperCase()}';
    }
    final sub = _jwtClaim(auth.accessToken, 'sub');
    if (sub != null && sub.isNotEmpty) {
      return 'user:$sub';
    }
    final email = _jwtClaim(auth.accessToken, 'email')?.trim();
    if (email != null && email.isNotEmpty) {
      return 'email:${email.toLowerCase()}';
    }
    final token = auth.accessToken?.trim();
    if (token != null && token.isNotEmpty) {
      return 'token:$token';
    }
    return _guestOwnerKey;
  }

  String? _jwtClaim(String? token, String claim) {
    if (token == null || token.isEmpty || !token.contains('.')) return null;
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final normalized = base64Url.normalize(parts[1]);
      final json = utf8.decode(base64Url.decode(normalized));
      final payload = jsonDecode(json);
      if (payload is! Map<String, dynamic>) return null;
      final value = payload[claim];
      return value is String ? value : null;
    } catch (_) {
      return null;
    }
  }

  void _assignGuestCartTo(String ownerKey) {
    final guest = _cartsByOwner[_guestOwnerKey];
    if (guest == null || guest.qtyById.isEmpty) return;
    final target = _cartsByOwner.putIfAbsent(ownerKey, _CartState.new);
    for (final e in guest.qtyById.entries) {
      final p = guest.products[e.key];
      if (p == null) continue;
      target.products[e.key] = p;
      target.qtyById[e.key] = (target.qtyById[e.key] ?? 0) + e.value;
    }
    guest.qtyById.clear();
    guest.products.clear();
  }

  void _clearGuestCart() {
    final guest = _cartsByOwner[_guestOwnerKey];
    if (guest == null) return;
    guest.qtyById.clear();
    guest.products.clear();
  }

  Future<String?> reserveOnServer(Product product, {int qty = 1}) async {
    final auth = _auth;
    final token = auth?.accessToken;
    if (auth == null || !auth.isAuthenticated || token == null || token.isEmpty) {
      return null;
    }
    try {
      final uri = Uri.parse('${auth.apiBase}/order/reserve');
      final r = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'productId': product.id,
              'quantity': qty,
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200 || r.statusCode == 201) return null;
      try {
        final j = jsonDecode(r.body);
        if (j is Map<String, dynamic>) {
          final m = j['message'];
          if (m is String && m.trim().isNotEmpty) {
            return m.trim();
          }
        }
      } catch (_) {}
      if (r.statusCode == 409) {
        return 'Dziękujemy za zainteresowanie. Ten produkt został właśnie zarezerwowany lub sprzedany chwilę temu.';
      }
      return 'Nie udało się dodać produktu do koszyka (HTTP ${r.statusCode}).';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> watchAvailabilityOnServer(String productId) async {
    final auth = _auth;
    final token = auth?.accessToken;
    if (auth == null || !auth.isAuthenticated || token == null || token.isEmpty) {
      return 'Zaloguj się, aby włączyć powiadomienie o dostępności.';
    }
    try {
      final uri = Uri.parse('${auth.apiBase}/order/watch-availability');
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
      if (r.statusCode == 200 || r.statusCode == 201) {
        final j = jsonDecode(r.body);
        if (j is Map<String, dynamic> && j['message'] is String) {
          return j['message'] as String;
        }
        return 'Powiadomienie o dostępności zostało włączone.';
      }
      return 'Nie udało się włączyć powiadomienia o dostępności.';
    } catch (_) {
      return 'Nie udało się włączyć powiadomienia o dostępności.';
    }
  }

  Future<List<Map<String, dynamic>>> fetchAvailabilityWatches() async {
    final auth = _auth;
    final token = auth?.accessToken;
    if (auth == null || !auth.isAuthenticated || token == null || token.isEmpty) {
      return const [];
    }
    try {
      final uri = Uri.parse('${auth.apiBase}/order/watch-availability');
      final r = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(
            const Duration(seconds: 12),
          );
      if (r.statusCode != 200) return const [];
      final j = jsonDecode(r.body);
      if (j is! List) return const [];
      return j.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> releaseOnServer(Product product, {int qty = 1}) async {
    final auth = _auth;
    final token = auth?.accessToken;
    if (auth == null || !auth.isAuthenticated || token == null || token.isEmpty) {
      return;
    }
    try {
      final uri = Uri.parse('${auth.apiBase}/order/release');
      await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'productId': product.id,
              'quantity': qty,
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> submitCartOnServer() async {
    final auth = _auth;
    final token = auth?.accessToken;
    if (auth == null || !auth.isAuthenticated || token == null || token.isEmpty) {
      return null;
    }
    try {
      final uri = Uri.parse('${auth.apiBase}/order/submit-cart');
      final r = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(const {}),
          )
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200 && r.statusCode != 201) return null;
      final j = jsonDecode(r.body);
      return j is Map<String, dynamic> ? j : null;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyReservationsSummary() async {
    final auth = _auth;
    final token = auth?.accessToken;
    if (auth == null || !auth.isAuthenticated || token == null || token.isEmpty) {
      return const [];
    }
    try {
      final uri = Uri.parse('${auth.apiBase}/order/my-reservations');
      final r = await http.get(uri, headers: {'Authorization': 'Bearer $token'}).timeout(
            const Duration(seconds: 12),
          );
      if (r.statusCode != 200) return const [];
      final j = jsonDecode(r.body);
      if (j is! List) return const [];
      return j.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>?> finalizeAcceptedOrder({
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    required String shippingMethod,
    required Map<String, dynamic> shippingTarget,
    bool saveToAddressBook = true,
    String? promoCode,
    String? giftCardCode,
    String? referralCode,
    String? customerNote,
  }) async {
    final auth = _auth;
    final token = auth?.accessToken;
    if (auth == null || !auth.isAuthenticated || token == null || token.isEmpty) {
      return null;
    }
    if (items.isEmpty) return null;
    try {
      final uri = Uri.parse('${auth.apiBase}/order/finalize');
      final r = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'items': items,
              'paymentMethod': paymentMethod,
              'shippingMethod': shippingMethod,
              'shippingTarget': shippingTarget,
              'saveToAddressBook': saveToAddressBook,
              if (promoCode != null && promoCode.trim().isNotEmpty)
                'promoCode': promoCode.trim(),
              if (giftCardCode != null && giftCardCode.trim().isNotEmpty)
                'giftCardCode': giftCardCode.trim(),
              if (referralCode != null && referralCode.trim().isNotEmpty)
                'referralCode': referralCode.trim(),
              if (customerNote != null && customerNote.trim().isNotEmpty)
                'customerNote': customerNote.trim(),
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200 && r.statusCode != 201) {
        try {
          final j = jsonDecode(r.body);
          if (j is Map<String, dynamic>) {
            final msg = j['message'];
            if (msg is String && msg.trim().isNotEmpty) {
              return {'_error': msg.trim()};
            }
          }
        } catch (_) {}
        return {'_error': 'Nie udało się sfinalizować zamówienia (HTTP ${r.statusCode}).'};
      }
      final j = jsonDecode(r.body);
      return j is Map<String, dynamic> ? j : null;
    } catch (e) {
      return {'_error': e.toString()};
    }
  }

  Future<Map<String, dynamic>?> fetchCheckoutOptions() async {
    final auth = _auth;
    final token = auth?.accessToken;
    if (auth == null || !auth.isAuthenticated || token == null || token.isEmpty) {
      return null;
    }
    try {
      final uri = Uri.parse('${auth.apiBase}/order/checkout/options');
      final r = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body);
      return j is Map<String, dynamic> ? j : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchCheckoutPreferences() async {
    final auth = _auth;
    final token = auth?.accessToken;
    if (auth == null || !auth.isAuthenticated || token == null || token.isEmpty) {
      return null;
    }
    try {
      final uri = Uri.parse('${auth.apiBase}/order/checkout/preferences');
      final r = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body);
      return j is Map<String, dynamic> ? j : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchOrderPayment(String orderId) async {
    final auth = _auth;
    final token = auth?.accessToken;
    if (auth == null || !auth.isAuthenticated || token == null || token.isEmpty) {
      return null;
    }
    try {
      final uri = Uri.parse('${auth.apiBase}/order/payments/$orderId');
      final r = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body);
      return j is Map<String, dynamic> ? j : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> simulateOrderPaymentSuccess(String orderId) async {
    final auth = _auth;
    final token = auth?.accessToken;
    if (auth == null || !auth.isAuthenticated || token == null || token.isEmpty) {
      return 'Zaloguj się, aby kontynuować.';
    }
    try {
      final uri = Uri.parse('${auth.apiBase}/order/payments/$orderId/simulate-success');
      final r = await http
          .post(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200 || r.statusCode == 201) {
        return null;
      }
      final j = jsonDecode(r.body);
      if (j is Map<String, dynamic>) {
        final msg = j['message'];
        if (msg is String && msg.trim().isNotEmpty) return msg.trim();
      }
      return 'Nie udało się zaksięgować płatności.';
    } catch (_) {
      return 'Nie udało się zaksięgować płatności.';
    }
  }

  /// Anuluj nieopłacone zamówienie w statusie PLACED (POST `/order/my-orders/:id/cancel`).
  Future<String?> cancelMyOrder(String orderId) async {
    final auth = _auth;
    final token = auth?.accessToken;
    if (auth == null || !auth.isAuthenticated || token == null || token.isEmpty) {
      return 'Zaloguj się, aby kontynuować.';
    }
    try {
      final uri = Uri.parse('${auth.apiBase}/order/my-orders/${Uri.encodeComponent(orderId)}/cancel');
      final r = await http
          .post(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200 || r.statusCode == 201) {
        return null;
      }
      final j = jsonDecode(r.body);
      if (j is Map<String, dynamic>) {
        final msg = j['message'];
        if (msg is List && msg.isNotEmpty) {
          final first = msg.first;
          if (first is Map && first['message'] is String) {
            return (first['message'] as String).trim();
          }
        }
        if (msg is String && msg.trim().isNotEmpty) return msg.trim();
      }
      return 'Nie udało się anulować zamówienia (HTTP ${r.statusCode}).';
    } catch (e) {
      return e.toString();
    }
  }

  Future<bool> saveCheckoutPreferences({
    String? preferredPaymentMethod,
    String? preferredShippingMethod,
    String? preferredAddressId,
  }) async {
    final auth = _auth;
    final token = auth?.accessToken;
    if (auth == null || !auth.isAuthenticated || token == null || token.isEmpty) {
      return false;
    }
    try {
      final uri = Uri.parse('${auth.apiBase}/order/checkout/preferences');
      final body = <String, dynamic>{
        'preferredPaymentMethod': preferredPaymentMethod,
        'preferredShippingMethod': preferredShippingMethod,
        'preferredAddressId': preferredAddressId,
      };
      final r = await http
          .patch(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));
      return r.statusCode == 200 || r.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAddressBook() async {
    final auth = _auth;
    final token = auth?.accessToken;
    if (auth == null || !auth.isAuthenticated || token == null || token.isEmpty) {
      return const [];
    }
    try {
      final uri = Uri.parse('${auth.apiBase}/order/checkout/address-book');
      final r = await http
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return const [];
      final j = jsonDecode(r.body);
      if (j is! List) return const [];
      return j.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, dynamic>?> upsertAddressBookEntry(Map<String, dynamic> payload) async {
    final auth = _auth;
    final token = auth?.accessToken;
    if (auth == null || !auth.isAuthenticated || token == null || token.isEmpty) {
      return null;
    }
    try {
      final id = payload['id']?.toString();
      final uri = id == null || id.isEmpty
          ? Uri.parse('${auth.apiBase}/order/checkout/address-book')
          : Uri.parse('${auth.apiBase}/order/checkout/address-book/$id');
      final method = id == null || id.isEmpty ? 'POST' : 'PATCH';
      final body = Map<String, dynamic>.from(payload)..remove('id');
      final r = await (method == 'POST'
              ? http.post(
                  uri,
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode(body),
                )
              : http.patch(
                  uri,
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode(body),
                ))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200 && r.statusCode != 201) return null;
      final j = jsonDecode(r.body);
      return j is Map<String, dynamic> ? j : null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> deleteAddressBookEntry(String id) async {
    final auth = _auth;
    final token = auth?.accessToken;
    if (auth == null || !auth.isAuthenticated || token == null || token.isEmpty) {
      return false;
    }
    try {
      final uri = Uri.parse('${auth.apiBase}/order/checkout/address-book/$id');
      final r = await http
          .delete(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 12));
      return r.statusCode == 200 || r.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  void removeQuantity(String productId, int qty) {
    if (qty <= 0) return;
    final current = _activeCart.qtyById[productId] ?? 0;
    if (current <= qty) {
      removeLine(productId);
      return;
    }
    _activeCart.qtyById[productId] = current - qty;
    notifyListeners();
    unawaited(_persistToStorage());
  }

  void reconcileWithServerReservations(List<Map<String, dynamic>> rows) {
    if (_auth?.isAuthenticated != true) return;
    final allowedByProduct = <String, int>{};
    for (final row in rows) {
      final productId = row['productId'] as String?;
      if (productId == null || productId.isEmpty) continue;
      final inCartQty = (row['inCartQty'] as num?)?.toInt() ?? 0;
      final pendingQty = (row['pendingQty'] as num?)?.toInt() ?? 0;
      final acceptedQty = (row['acceptedQty'] as num?)?.toInt() ?? 0;
      final rejectedQty = (row['rejectedQty'] as num?)?.toInt() ?? 0;
      final allowed = inCartQty + pendingQty + acceptedQty + rejectedQty;
      allowedByProduct[productId] = allowed;
    }

    var changed = false;
    final keys = _activeCart.qtyById.keys.toList(growable: false);
    for (final productId in keys) {
      final allowed = allowedByProduct[productId] ?? 0;
      final current = _activeCart.qtyById[productId] ?? 0;
      if (allowed <= 0) {
        _activeCart.qtyById.remove(productId);
        _activeCart.products.remove(productId);
        changed = true;
        continue;
      }
      if (current > allowed) {
        _activeCart.qtyById[productId] = allowed;
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
      unawaited(_persistToStorage());
    }
  }

  Future<void> _restoreFromStorage() async {
    try {
      final raw = await cartStorageGetCartsJson();
      if (raw == null || raw.isEmpty) {
        _restored = true;
        _switchOwner(forceNotify: true);
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _restored = true;
        _switchOwner(forceNotify: true);
        return;
      }
      for (final entry in decoded.entries) {
        final owner = entry.key;
        final stateJson = entry.value;
        if (stateJson is! Map<String, dynamic>) continue;
        final state = _cartStateFromJson(stateJson);
        if (state.qtyById.isEmpty) continue;
        _cartsByOwner[owner] = state;
      }
    } catch (_) {
      // Ignorujemy uszkodzony zapis; użytkownik dalej może pracować na świeżym koszyku.
    }
    _restored = true;
    _switchOwner(forceNotify: true);
  }

  Future<void> _persistToStorage() async {
    if (!_restored) return;
    final payload = <String, dynamic>{};
    for (final e in _cartsByOwner.entries) {
      if (e.value.qtyById.isEmpty) continue;
      payload[e.key] = _cartStateToJson(e.value);
    }
    await cartStorageSetCartsJson(jsonEncode(payload));
  }

  Map<String, dynamic> _cartStateToJson(_CartState state) {
    return {
      'lines': state.qtyById.entries.map((e) {
        final p = state.products[e.key];
        if (p == null) return null;
        return {
          'id': p.id,
          'name': p.name,
          'pricePln': p.pricePln,
          'imageUrl': p.imageUrl,
          'category': p.category.name,
          'condition': p.condition.name,
          'qty': e.value,
        };
      }).whereType<Map<String, dynamic>>().toList(),
    };
  }

  _CartState _cartStateFromJson(Map<String, dynamic> json) {
    final state = _CartState();
    final lines = json['lines'];
    if (lines is! List) return state;
    for (final line in lines) {
      if (line is! Map<String, dynamic>) continue;
      final product = _productFromJson(line);
      final qty = (line['qty'] as num?)?.toInt() ?? 0;
      if (product == null || qty <= 0) continue;
      state.products[product.id] = product;
      state.qtyById[product.id] = qty;
    }
    return state;
  }

  Product? _productFromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    final imageUrl = json['imageUrl'] as String?;
    final pricePln = (json['pricePln'] as num?)?.toDouble();
    final categoryName = json['category'] as String?;
    final conditionName = json['condition'] as String?;
    if (id == null ||
        name == null ||
        imageUrl == null ||
        pricePln == null ||
        categoryName == null ||
        conditionName == null) {
      return null;
    }
    final category = ProductCategory.values.where((e) => e.name == categoryName);
    final condition =
        ProductCondition.values.where((e) => e.name == conditionName);
    if (category.isEmpty || condition.isEmpty) return null;
    return Product(
      id: id,
      name: name,
      pricePln: pricePln,
      imageUrl: imageUrl,
      category: category.first,
      condition: condition.first,
    );
  }
}

class _CartState {
  final Map<String, int> qtyById = {};
  final Map<String, Product> products = {};
}
