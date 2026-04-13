class StaffProduct {
  const StaffProduct({
    required this.id,
    required this.idDotykacka,
    required this.name,
    required this.priceRaw,
    required this.status,
    required this.pendingQuantity,
  });

  final String id;
  final String idDotykacka;
  final String name;
  final String priceRaw;
  final String status;
  final int pendingQuantity;

  factory StaffProduct.fromJson(Map<String, dynamic> j) {
    return StaffProduct(
      id: j['id'] as String,
      idDotykacka: j['idDotykacka'] as String? ?? j['id_dotykacka'] as String? ?? '',
      name: j['name'] as String,
      priceRaw: j['price']?.toString() ?? '0',
      status: j['status'] as String? ?? '',
      pendingQuantity: (j['pendingQuantity'] as num?)?.toInt() ?? 1,
    );
  }
}

class StaffCustomerProfile {
  const StaffCustomerProfile({
    required this.userId,
    this.email,
    required this.role,
    required this.points,
    required this.rank,
    required this.permissions,
  });

  final String userId;
  final String? email;
  final String role;
  final int points;
  final String rank;
  final List<String> permissions;

  factory StaffCustomerProfile.fromJson(Map<String, dynamic> j) {
    return StaffCustomerProfile(
      userId: j['userId'] as String? ?? j['user_id'] as String? ?? '',
      email: j['email'] as String?,
      role: j['role'] as String? ?? '',
      points: (j['points'] as num?)?.toInt() ?? 0,
      rank: j['rank'] as String? ?? '',
      permissions: (j['permissions'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

class StaffOrder {
  const StaffOrder({
    required this.id,
    required this.userId,
    required this.customerEmail,
    required this.createdAt,
    required this.status,
    required this.totalAmountRaw,
    required this.paymentMethod,
    required this.paymentProvider,
    required this.paymentStatus,
    required this.paymentReference,
    required this.itemCount,
    required this.items,
  });

  final String id;
  final String userId;
  final String? customerEmail;
  final String createdAt;
  final String status;
  final String totalAmountRaw;
  final String paymentMethod;
  final String paymentProvider;
  final String paymentStatus;
  final String? paymentReference;
  final int itemCount;
  final List<StaffOrderItem> items;

  factory StaffOrder.fromJson(Map<String, dynamic> j) {
    return StaffOrder(
      id: j['id'] as String? ?? '',
      userId: j['userId'] as String? ?? '',
      customerEmail: j['customerEmail'] as String?,
      createdAt: j['createdAt'] as String? ?? '',
      status: j['status'] as String? ?? '',
      totalAmountRaw: j['totalAmount']?.toString() ?? '0',
      paymentMethod: j['paymentMethod'] as String? ?? '',
      paymentProvider: j['paymentProvider'] as String? ?? '',
      paymentStatus: j['paymentStatus'] as String? ?? '',
      paymentReference: j['paymentReference'] as String?,
      itemCount: (j['itemCount'] as num?)?.toInt() ?? 0,
      items: (j['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StaffOrderItem.fromJson)
          .toList(),
    );
  }
}

class StaffOrderItem {
  const StaffOrderItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.priceRaw,
    required this.lineTotalRaw,
  });

  final String productId;
  final String name;
  final int quantity;
  final String priceRaw;
  final String lineTotalRaw;

  factory StaffOrderItem.fromJson(Map<String, dynamic> j) {
    return StaffOrderItem(
      productId: j['productId'] as String? ?? '',
      name: j['name'] as String? ?? '',
      quantity: (j['quantity'] as num?)?.toInt() ?? 0,
      priceRaw: j['price']?.toString() ?? '0',
      lineTotalRaw: j['lineTotal']?.toString() ?? '0',
    );
  }
}

class StaffPermissionUser {
  const StaffPermissionUser({
    required this.userId,
    required this.email,
    required this.role,
    required this.permissions,
  });

  final String userId;
  final String? email;
  final String role;
  final List<String> permissions;

  factory StaffPermissionUser.fromJson(Map<String, dynamic> j) {
    return StaffPermissionUser(
      userId: j['userId'] as String? ?? '',
      email: j['email'] as String?,
      role: j['role'] as String? ?? '',
      permissions: (j['permissions'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

class StaffApiException implements Exception {
  StaffApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  String toString() => 'HTTP $statusCode: $body';
}

class DotykackaDevStockRow {
  const DotykackaDevStockRow({
    required this.idDotykacka,
    required this.stockQty,
  });

  final String idDotykacka;
  final int stockQty;

  factory DotykackaDevStockRow.fromJson(Map<String, dynamic> j) {
    return DotykackaDevStockRow(
      idDotykacka: j['idDotykacka'] as String? ?? '',
      stockQty: (j['stockQty'] as num?)?.toInt() ?? 0,
    );
  }
}

String? extractCustomerUuid(String raw) {
  final re = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );
  final m = re.firstMatch(raw.trim());
  return m?.group(0);
}
