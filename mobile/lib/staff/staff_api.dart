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

  Future<({bool enabled, List<DotykackaDevStockRow> rows})>
      fetchDotykackaDevStock() async {
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

  Future<List<StaffOrder>> fetchOrders({String? status}) async {
    final uri = Uri.parse('${_session.apiBase}/staff/orders').replace(
      queryParameters: status != null && status.trim().isNotEmpty
          ? {'status': status.trim()}
          : null,
    );
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

  Future<Map<String, dynamic>> fetchOrderDetail(String orderId) async {
    final uri = Uri.parse(
      '${_session.apiBase}/staff/orders/${Uri.encodeComponent(orderId)}',
    );
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final j = jsonDecode(r.body);
    if (j is Map<String, dynamic>) return j;
    return const {};
  }

  Future<Map<String, dynamic>> postStaffOrderNote(
      String orderId, String body) async {
    final uri = Uri.parse(
      '${_session.apiBase}/staff/orders/${Uri.encodeComponent(orderId)}/notes',
    );
    final r = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'body': body}),
    );
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final j = jsonDecode(r.body);
    return j is Map<String, dynamic> ? j : const {};
  }

  Future<Map<String, dynamic>> patchProductMerchandising(
    String productId, {
    required bool isFeatured,
    String? subtitle,
  }) async {
    final uri = Uri.parse(
      '${_session.apiBase}/staff/products/${Uri.encodeComponent(productId)}/merchandising',
    );
    final r = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode({
        'isFeatured': isFeatured,
        'subtitle': subtitle,
      }),
    );
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<StaffCostingImportResult> importCostingFile({
    required List<int> bytes,
    required String fileName,
  }) async {
    final t = _session.accessToken;
    if (t == null || t.isEmpty) {
      throw StaffApiException(401, 'Brak tokenu dostępu');
    }
    final uri = Uri.parse('${_session.apiBase}/staff/products/costing/import');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $t'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );
    final streamed = await req.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw StaffApiException(response.statusCode, response.body);
    }
    final j = jsonDecode(response.body);
    if (j is! Map<String, dynamic>) {
      throw StaffApiException(500, 'Nieprawidłowa odpowiedź importu');
    }
    return StaffCostingImportResult.fromJson(j);
  }

  Future<Map<String, dynamic>> runFinancialIntelligenceAnalysis() async {
    final uri =
        Uri.parse('${_session.apiBase}/staff/financial-intelligence/analyze');
    final r = await http.post(uri, headers: _headers());
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final j = jsonDecode(r.body);
    if (j is! Map<String, dynamic>) return const {};
    return j;
  }

  Future<Map<String, dynamic>> runProfitGuardGeneration() async {
    final uri = Uri.parse('${_session.apiBase}/admin/ai/proposals/generate');
    final r = await http.post(uri, headers: _headers());
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final j = jsonDecode(r.body);
    if (j is! Map<String, dynamic>) return const {};
    return j;
  }

  Future<List<FinancialAiProposal>> fetchAdminAiProposals({
    String? status,
  }) async {
    final uri = Uri.parse('${_session.apiBase}/admin/ai/proposals').replace(
      queryParameters: (status != null && status.trim().isNotEmpty)
          ? {'status': status.trim()}
          : null,
    );
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final list = jsonDecode(r.body);
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(FinancialAiProposal.fromJson)
        .toList();
  }

  Future<List<FinancialAiProposal>> fetchFinancialAiProposals({
    String? status,
  }) async {
    final uri =
        Uri.parse('${_session.apiBase}/staff/financial-intelligence/proposals')
            .replace(
      queryParameters: (status != null && status.trim().isNotEmpty)
          ? {'status': status.trim()}
          : null,
    );
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final list = jsonDecode(r.body);
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(FinancialAiProposal.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> acceptFinancialAiProposal(
      String proposalId) async {
    final uri = Uri.parse(
      '${_session.apiBase}/staff/financial-intelligence/proposals/${Uri.encodeComponent(proposalId)}/accept-and-launch-marketing',
    );
    final r = await http.post(uri, headers: _headers());
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final j = jsonDecode(r.body);
    if (j is! Map<String, dynamic>) return const {};
    return j;
  }

  Future<Map<String, dynamic>> rejectFinancialAiProposal(
      String proposalId) async {
    final uri = Uri.parse(
      '${_session.apiBase}/staff/financial-intelligence/proposals/${Uri.encodeComponent(proposalId)}/reject',
    );
    final r = await http.post(uri, headers: _headers());
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final j = jsonDecode(r.body);
    if (j is! Map<String, dynamic>) return const {};
    return j;
  }

  Future<List<MarketingDraft>> fetchMarketingDrafts() async {
    final uri = Uri.parse('${_session.apiBase}/staff/marketing/drafts');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final list = jsonDecode(r.body);
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(MarketingDraft.fromJson)
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchCatalogProducts({
    String? q,
    int limit = 120,
  }) async {
    final query = <String, String>{
      'offset': '0',
      'limit': '${limit.clamp(1, 200)}',
    };
    if (q != null && q.trim().isNotEmpty) {
      query['q'] = q.trim();
    }
    final uri = Uri.parse('${_session.apiBase}/products').replace(
      queryParameters: query,
    );
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final list = jsonDecode(r.body);
    if (list is! List) return const [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<Map<String, dynamic>>> fetchReviewsModeration() async {
    final uri = Uri.parse('${_session.apiBase}/staff/reviews');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final list = jsonDecode(r.body);
    if (list is! List) return const [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> patchReviewVisibility(
      String reviewId, bool isVisible) async {
    final uri = Uri.parse(
      '${_session.apiBase}/staff/reviews/${Uri.encodeComponent(reviewId)}',
    );
    final r = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode({'isVisible': isVisible}),
    );
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
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

  Future<StaffOrder> patchOrderPaymentStatus(
      String orderId, String paymentStatus) async {
    final uri =
        Uri.parse('${_session.apiBase}/staff/orders/$orderId/payment-status');
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

  Future<Map<String, dynamic>> fetchAnalyticsSummary() async {
    final uri = Uri.parse('${_session.apiBase}/staff/analytics/summary');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final j = jsonDecode(r.body);
    if (j is Map<String, dynamic>) return j;
    return <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> fetchLowStock({int threshold = 3}) async {
    final uri =
        Uri.parse('${_session.apiBase}/staff/analytics/low-stock').replace(
      queryParameters: {'threshold': '$threshold'},
    );
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final rows = jsonDecode(r.body);
    if (rows is! List) return const [];
    return rows.whereType<Map<String, dynamic>>().toList();
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

  Future<List<Map<String, dynamic>>> fetchReturnRequests() async {
    final uri = Uri.parse('${_session.apiBase}/staff/returns');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final rows = jsonDecode(r.body);
    if (rows is! List) return const [];
    return rows.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> patchReturnRequest(
    String id, {
    required String status,
    String? staffNote,
  }) async {
    final uri = Uri.parse('${_session.apiBase}/staff/returns/$id');
    final body = <String, dynamic>{'status': status};
    if (staffNote != null) body['staffNote'] = staffNote;
    final r = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode(body),
    );
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
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
    return StaffPermissionUser.fromJson(
        jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<StaffAuditLogsPage> fetchAuditLogs({
    int offset = 0,
    int limit = 50,
    String? userId,
    String? userEmail,
    String? action,
    String? resourceType,
  }) async {
    final query = <String, String>{
      'offset': '${offset < 0 ? 0 : offset}',
      'limit': '${limit.clamp(1, 200)}',
    };
    if (userId != null && userId.trim().isNotEmpty) {
      query['userId'] = userId.trim();
    }
    if (userEmail != null && userEmail.trim().isNotEmpty) {
      query['userEmail'] = userEmail.trim();
    }
    if (action != null && action.trim().isNotEmpty) {
      query['action'] = action.trim();
    }
    if (resourceType != null && resourceType.trim().isNotEmpty) {
      query['resourceType'] = resourceType.trim();
    }
    final uri = Uri.parse('${_session.apiBase}/staff/audit-logs').replace(
      queryParameters: query,
    );
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final j = jsonDecode(r.body);
    if (j is! Map<String, dynamic>) {
      return const StaffAuditLogsPage(total: 0, offset: 0, limit: 0, rows: []);
    }
    return StaffAuditLogsPage.fromJson(j);
  }

  // --- CMS / support / experiments / gift cards (uprawnienia manage.*) ---

  Future<List<Map<String, dynamic>>> fetchCmsPagesStaff() async {
    final uri = Uri.parse('${_session.apiBase}/staff/cms/pages');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final list = jsonDecode(r.body);
    if (list is! List) return const [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> upsertCmsPage(Map<String, dynamic> body) async {
    final uri = Uri.parse('${_session.apiBase}/staff/cms/pages');
    final r = await http.post(uri, headers: _headers(), body: jsonEncode(body));
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw StaffApiException(r.statusCode, r.body);
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchSupportTicketsStaff() async {
    final uri = Uri.parse('${_session.apiBase}/staff/support/tickets');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final list = jsonDecode(r.body);
    if (list is! List) return const [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>?> fetchSupportTicketDetail(
      String ticketId) async {
    final uri = Uri.parse(
      '${_session.apiBase}/staff/support/tickets/${Uri.encodeComponent(ticketId)}',
    );
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final j = jsonDecode(r.body);
    if (j is Map<String, dynamic>) return j;
    return null;
  }

  Future<Map<String, dynamic>> postSupportStaffReply(
    String ticketId,
    String message,
  ) async {
    final uri = Uri.parse(
      '${_session.apiBase}/staff/support/tickets/${Uri.encodeComponent(ticketId)}/messages',
    );
    final r = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'body': message}),
    );
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw StaffApiException(r.statusCode, r.body);
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchExperimentsStaff() async {
    final uri = Uri.parse('${_session.apiBase}/staff/experiments');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final list = jsonDecode(r.body);
    if (list is! List) return const [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> upsertExperimentStaff(
      Map<String, dynamic> body) async {
    final uri = Uri.parse('${_session.apiBase}/staff/experiments');
    final r = await http.post(uri, headers: _headers(), body: jsonEncode(body));
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw StaffApiException(r.statusCode, r.body);
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patchExperimentActive(
      String key, bool active) async {
    final uri = Uri.parse(
      '${_session.apiBase}/staff/experiments/${Uri.encodeComponent(key)}/active',
    );
    final r = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode({'active': active}),
    );
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> fetchGiftCardsStaff() async {
    final uri = Uri.parse('${_session.apiBase}/staff/gift-cards');
    final r = await http.get(uri, headers: _headers());
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    final list = jsonDecode(r.body);
    if (list is! List) return const [];
    return list.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> createGiftCardStaff(
      Map<String, dynamic> body) async {
    final uri = Uri.parse('${_session.apiBase}/staff/gift-cards');
    final r = await http.post(uri, headers: _headers(), body: jsonEncode(body));
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw StaffApiException(r.statusCode, r.body);
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patchGiftCardActive(
      String id, bool active) async {
    final uri = Uri.parse(
      '${_session.apiBase}/staff/gift-cards/${Uri.encodeComponent(id)}/active',
    );
    final r = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode({'active': active}),
    );
    if (r.statusCode != 200) {
      throw StaffApiException(r.statusCode, r.body);
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
