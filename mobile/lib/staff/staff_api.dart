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
}
