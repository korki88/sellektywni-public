class StaffProduct {
  const StaffProduct({
    required this.id,
    required this.idDotykacka,
    required this.name,
    required this.priceRaw,
    required this.status,
    required this.pendingQuantity,
    this.subtitle,
    this.isFeatured = false,
  });

  final String id;
  final String idDotykacka;
  final String name;
  final String priceRaw;
  final String status;
  final int pendingQuantity;
  final String? subtitle;
  final bool isFeatured;

  factory StaffProduct.fromJson(Map<String, dynamic> j) {
    return StaffProduct(
      id: j['id'] as String,
      idDotykacka: j['idDotykacka'] as String? ?? j['id_dotykacka'] as String? ?? '',
      name: j['name'] as String,
      priceRaw: j['price']?.toString() ?? '0',
      status: j['status'] as String? ?? '',
      pendingQuantity: (j['pendingQuantity'] as num?)?.toInt() ?? 1,
      subtitle: j['subtitle'] as String?,
      isFeatured: j['isFeatured'] == true,
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
    required this.shippingMethod,
    required this.paymentMethod,
    required this.paymentProvider,
    required this.paymentStatus,
    required this.paymentReference,
    required this.itemCount,
    required this.items,
    this.customerNote,
    this.staffNotePreview,
  });

  final String id;
  final String userId;
  final String? customerEmail;
  final String createdAt;
  final String status;
  final String totalAmountRaw;
  final String shippingMethod;
  final String paymentMethod;
  final String paymentProvider;
  final String paymentStatus;
  final String? paymentReference;
  final int itemCount;
  final List<StaffOrderItem> items;
  final String? customerNote;
  final String? staffNotePreview;

  factory StaffOrder.fromJson(Map<String, dynamic> j) {
    return StaffOrder(
      id: j['id'] as String? ?? '',
      userId: j['userId'] as String? ?? '',
      customerEmail: j['customerEmail'] as String?,
      createdAt: j['createdAt'] as String? ?? '',
      status: j['status'] as String? ?? '',
      totalAmountRaw: j['totalAmount']?.toString() ?? '0',
      shippingMethod: j['shippingMethod'] as String? ?? '',
      paymentMethod: j['paymentMethod'] as String? ?? '',
      paymentProvider: j['paymentProvider'] as String? ?? '',
      paymentStatus: j['paymentStatus'] as String? ?? '',
      paymentReference: j['paymentReference'] as String?,
      itemCount: (j['itemCount'] as num?)?.toInt() ?? 0,
      customerNote: j['customerNote'] as String?,
      staffNotePreview: j['staffNotePreview'] as String?,
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

class StaffAuditLog {
  const StaffAuditLog({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.action,
    required this.resourceType,
    required this.resourceId,
    required this.ipAddress,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String userEmail;
  final String action;
  final String resourceType;
  final String resourceId;
  final String? ipAddress;
  final String createdAt;

  factory StaffAuditLog.fromJson(Map<String, dynamic> j) {
    return StaffAuditLog(
      id: j['id'] as String? ?? '',
      userId: j['userId'] as String? ?? '',
      userEmail: j['userEmail'] as String? ?? '',
      action: j['action'] as String? ?? '',
      resourceType: j['resourceType'] as String? ?? 'UNKNOWN',
      resourceId: j['resourceId'] as String? ?? 'UNKNOWN',
      ipAddress: j['ipAddress'] as String?,
      createdAt: j['createdAt'] as String? ?? '',
    );
  }
}

class StaffAuditLogsPage {
  const StaffAuditLogsPage({
    required this.total,
    required this.offset,
    required this.limit,
    required this.rows,
  });

  final int total;
  final int offset;
  final int limit;
  final List<StaffAuditLog> rows;

  factory StaffAuditLogsPage.fromJson(Map<String, dynamic> j) {
    return StaffAuditLogsPage(
      total: (j['total'] as num?)?.toInt() ?? 0,
      offset: (j['offset'] as num?)?.toInt() ?? 0,
      limit: (j['limit'] as num?)?.toInt() ?? 0,
      rows: (j['rows'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StaffAuditLog.fromJson)
          .toList(),
    );
  }
}

class StaffCostingImportResult {
  const StaffCostingImportResult({
    required this.fileName,
    required this.rowsTotal,
    required this.updatedProducts,
    required this.upsertedSuppliers,
    required this.warnings,
  });

  final String fileName;
  final int rowsTotal;
  final int updatedProducts;
  final int upsertedSuppliers;
  final List<String> warnings;

  factory StaffCostingImportResult.fromJson(Map<String, dynamic> j) {
    return StaffCostingImportResult(
      fileName: j['fileName'] as String? ?? '',
      rowsTotal: (j['rowsTotal'] as num?)?.toInt() ?? 0,
      updatedProducts: (j['updatedProducts'] as num?)?.toInt() ?? 0,
      upsertedSuppliers: (j['upsertedSuppliers'] as num?)?.toInt() ?? 0,
      warnings: (j['warnings'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class FinancialAiProposal {
  const FinancialAiProposal({
    required this.id,
    required this.type,
    required this.status,
    required this.currentPriceRaw,
    required this.suggestedPriceRaw,
    required this.discountPercentRaw,
    required this.riskScore,
    required this.rationale,
    required this.createdAt,
    this.productId,
    this.productName,
    this.supplierName,
    this.paymentTermsDays,
  });

  final String id;
  final String type;
  final String status;
  final String currentPriceRaw;
  final String suggestedPriceRaw;
  final String discountPercentRaw;
  final int riskScore;
  final String rationale;
  final String createdAt;
  final String? productId;
  final String? productName;
  final String? supplierName;
  final int? paymentTermsDays;

  factory FinancialAiProposal.fromJson(Map<String, dynamic> j) {
    final product = j['product'];
    final supplier =
        product is Map<String, dynamic> ? product['supplier'] : null;
    return FinancialAiProposal(
      id: j['id'] as String? ?? '',
      type: j['type'] as String? ?? '',
      status: j['status'] as String? ?? '',
      currentPriceRaw: j['currentPrice']?.toString() ?? '0',
      suggestedPriceRaw: j['suggestedPrice']?.toString() ?? '0',
      discountPercentRaw: j['discountPercent']?.toString() ?? '0',
      riskScore: (j['riskScore'] as num?)?.toInt() ?? 0,
      rationale: j['rationale']?.toString() ?? '',
      createdAt: j['createdAt']?.toString() ?? '',
      productId: product is Map<String, dynamic>
          ? product['id']?.toString()
          : null,
      productName: product is Map<String, dynamic>
          ? product['name']?.toString()
          : null,
      supplierName: supplier is Map<String, dynamic>
          ? supplier['name']?.toString()
          : null,
      paymentTermsDays: supplier is Map<String, dynamic>
          ? (supplier['paymentTermsDays'] as num?)?.toInt()
          : null,
    );
  }
}

class MarketingDraft {
  const MarketingDraft({
    required this.id,
    required this.status,
    required this.caption,
    required this.suggestImage,
    required this.pushVintage,
    required this.pushGold,
    required this.pushSilver,
    required this.createdAt,
    this.productName,
    this.productPriceRaw,
    this.riskScore,
    this.discountPercentRaw,
  });

  final String id;
  final String status;
  final String caption;
  final String suggestImage;
  final String pushVintage;
  final String pushGold;
  final String pushSilver;
  final String createdAt;
  final String? productName;
  final String? productPriceRaw;
  final int? riskScore;
  final String? discountPercentRaw;

  factory MarketingDraft.fromJson(Map<String, dynamic> j) {
    final product = j['product'];
    final ai = j['aiProposal'];
    return MarketingDraft(
      id: j['id'] as String? ?? '',
      status: j['status'] as String? ?? '',
      caption: j['caption']?.toString() ?? '',
      suggestImage: j['suggestImage']?.toString() ?? '',
      pushVintage: j['pushVintage']?.toString() ?? '',
      pushGold: j['pushGold']?.toString() ?? '',
      pushSilver: j['pushSilver']?.toString() ?? '',
      createdAt: j['createdAt']?.toString() ?? '',
      productName:
          product is Map<String, dynamic> ? product['name']?.toString() : null,
      productPriceRaw:
          product is Map<String, dynamic> ? product['price']?.toString() : null,
      riskScore: ai is Map<String, dynamic>
          ? (ai['riskScore'] as num?)?.toInt()
          : null,
      discountPercentRaw:
          ai is Map<String, dynamic> ? ai['discountPercent']?.toString() : null,
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
