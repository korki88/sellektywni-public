import 'dart:convert';

import 'package:http/http.dart' as http;

import '../providers/auth_session.dart';
import 'staff_models.dart';

class StaffApi {
  StaffApi(this._session);

  final AuthSession _session;

  Map<String, String> _headers() {
    final t = _session.accessToken;
    if (t == null || t.isEmpty) {
      throw StaffApiException(401, 'Brak tokenu dostępu');
    }
    return {
      'Authorization': 'Bearer $t',
      'Content-Type': 'application/json',
    };
  }

  Future<List<StaffProduct>> fetchPendingProducts() async {
    final uri = Uri.parse('${_session.apiBase}/staff/products/pending');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final list = jsonDecode(r.body) as List<dynamic>;
    return list
        .map((e) => StaffProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StaffProduct> acceptProduct(String productId) async {
    final uri = Uri.parse(
      '${_session.apiBase}/staff/products/$productId/accept',
    );
    final r = await http.patch(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return StaffProduct.fromJson(j);
  }

  Future<StaffProduct> rejectProduct(String productId) async {
    final uri = Uri.parse(
      '${_session.apiBase}/staff/products/$productId/reject',
    );
    final r = await http.patch(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return StaffProduct.fromJson(j);
  }

  Future<StaffCustomerProfile> fetchCustomer(String userId) async {
    final uri = Uri.parse('${_session.apiBase}/staff/customers/$userId');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return StaffCustomerProfile.fromJson(j);
  }

  Future<StaffCustomerProfile> patchCustomer(
    String userId, {
    String? rank,
    int? addPoints,
    int? setPoints,
  }) async {
    final uri = Uri.parse('${_session.apiBase}/staff/customers/$userId');
    final body = <String, dynamic>{};
    if (rank != null) body['rank'] = rank;
    if (addPoints != null) body['addPoints'] = addPoints;
    if (setPoints != null) body['setPoints'] = setPoints;
    final r = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return StaffCustomerProfile.fromJson(j);
  }

  Future<({bool enabled, List<DotykackaDevStockRow> rows})> fetchDotykackaDevStock() async {
    final uri = Uri.parse('${_session.apiBase}/dotykacka/dev/stock');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final rowsRaw = j['rows'];
    final rows = rowsRaw is List
        ? rowsRaw
            .whereType<Map<String, dynamic>>()
            .map(DotykackaDevStockRow.fromJson)
            .toList()
        : <DotykackaDevStockRow>[];
    return (
      enabled: j['enabled'] as bool? ?? false,
      rows: rows,
    );
  }

  Future<void> setDotykackaDevStock(String idDotykacka, int stockQty) async {
    final uri = Uri.parse('${_session.apiBase}/dotykacka/dev/stock');
    final r = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'idDotykacka': idDotykacka,
        'stockQty': stockQty,
      }),
    );
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
  }

  Future<List<StaffOrder>> fetchOrders() async {
    final uri = Uri.parse('${_session.apiBase}/staff/orders');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final rows = jsonDecode(r.body) as List<dynamic>;
    return rows
        .whereType<Map<String, dynamic>>()
        .map(StaffOrder.fromJson)
        .toList();
  }

  Future<StaffOrder> patchOrderStatus(String orderId, String status) async {
    final uri = Uri.parse('${_session.apiBase}/staff/orders/$orderId/status');
    final r = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode({'status': status}),
    );
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    return StaffOrder.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<StaffOrder> patchOrderPaymentStatus(String orderId, String paymentStatus) async {
    final uri = Uri.parse('${_session.apiBase}/staff/orders/$orderId/payment-status');
    final r = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode({'paymentStatus': paymentStatus}),
    );
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    return StaffOrder.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> fetchShippingProviders() async {
    final uri = Uri.parse('${_session.apiBase}/shipping/providers');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    return (jsonDecode(r.body) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchInpostPoints({
    String? postalCode,
    String? city,
  }) async {
    final query = <String, String>{};
    if (postalCode != null && postalCode.trim().isNotEmpty) {
      query['postalCode'] = postalCode.trim();
    }
    if (city != null && city.trim().isNotEmpty) {
      query['city'] = city.trim();
    }
    final uri = Uri.parse('${_session.apiBase}/shipping/points/inpost')
        .replace(queryParameters: query.isEmpty ? null : query);
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    return (jsonDecode(r.body) as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// Wszystkie przewoźnicy naraz (InPost live + DPD/DHL/Poczta gdy skonfigurowane).
  Future<Map<String, dynamic>> fetchShippingPointsSuggest({
    String? postalCode,
    String? city,
  }) async {
    final query = <String, String>{};
    if (postalCode != null && postalCode.trim().isNotEmpty) {
      query['postalCode'] = postalCode.trim();
    }
    if (city != null && city.trim().isNotEmpty) {
      query['city'] = city.trim();
    }
    final uri = Uri.parse('${_session.apiBase}/shipping/points/suggest')
        .replace(queryParameters: query.isEmpty ? null : query);
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final j = jsonDecode(r.body);
    if (j is Map<String, dynamic>) return j;
    return <String, dynamic>{};
  }

  Future<({List<String> availablePermissions, List<StaffPermissionUser> users})>
      fetchPermissionUsers() async {
    final uri = Uri.parse('${_session.apiBase}/staff/permissions/users');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final available = (j['availablePermissions'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
    final users = (j['users'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(StaffPermissionUser.fromJson)
        .toList();
    return (availablePermissions: available, users: users);
  }

  Future<StaffPermissionUser> updatePermissions(
    String userId,
    List<String> permissions,
  ) async {
    final uri = Uri.parse('${_session.apiBase}/staff/permissions/$userId');
    final r = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode({'permissions': permissions}),
    );
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    return StaffPermissionUser.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
}
