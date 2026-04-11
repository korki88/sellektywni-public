class StaffProduct {
  const StaffProduct({
    required this.id,
    required this.idDotykacka,
    required this.name,
    required this.priceRaw,
    required this.status,
  });

  final String id;
  final String idDotykacka;
  final String name;
  final String priceRaw;
  final String status;

  factory StaffProduct.fromJson(Map<String, dynamic> j) {
    return StaffProduct(
      id: j['id'] as String,
      idDotykacka: j['idDotykacka'] as String? ?? j['id_dotykacka'] as String? ?? '',
      name: j['name'] as String,
      priceRaw: j['price']?.toString() ?? '0',
      status: j['status'] as String? ?? '',
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
  });

  final String userId;
  final String? email;
  final String role;
  final int points;
  final String rank;

  factory StaffCustomerProfile.fromJson(Map<String, dynamic> j) {
    return StaffCustomerProfile(
      userId: j['userId'] as String? ?? j['user_id'] as String? ?? '',
      email: j['email'] as String?,
      role: j['role'] as String? ?? '',
      points: (j['points'] as num?)?.toInt() ?? 0,
      rank: j['rank'] as String? ?? '',
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

String? extractCustomerUuid(String raw) {
  final re = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );
  final m = re.firstMatch(raw.trim());
  return m?.group(0);
}
