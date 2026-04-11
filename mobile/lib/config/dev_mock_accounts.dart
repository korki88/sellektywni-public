/// Prefiks Bearer tokenu dev-mock (bez Supabase / bez wymogu działającego API).
const String kDevMockTokenPrefix = 'dev-mock:';

/// Czy [token] to logowanie dev-mock (offline / dummy profil w aplikacji).
bool isDevMockBearerToken(String? token) {
  final t = token?.trim();
  if (t == null || t.isEmpty) return false;
  return t.startsWith(kDevMockTokenPrefix);
}

/// Rola z tokenu `dev-mock:OWNER` itd., albo null.
String? devMockRoleFromBearerToken(String? token) {
  if (!isDevMockBearerToken(token)) return null;
  final rest = token!.trim().substring(kDevMockTokenPrefix.length).trim();
  if (rest.isEmpty) return null;
  return rest;
}

/// Pola profilu wyłącznie do UI (DevMode bez integracji z API).
class DevMockProfileFields {
  const DevMockProfileFields({
    required this.role,
    required this.email,
    required this.points,
    required this.rank,
  });

  final String role;
  final String email;
  final int points;
  final String rank;
}

/// Token `dev-mock:…` dla [role] (`OWNER` / `STAFF` / `CUSTOMER`), albo null.
String? devMockTokenForPreviewRole(String role) {
  final r = role.trim().toUpperCase();
  if (r == 'OWNER' || r == 'STAFF' || r == 'CUSTOMER') {
    return '$kDevMockTokenPrefix$r';
  }
  return null;
}

/// Dummy dane dla tokenu dev-mock; null gdy to nie token dev-mock.
DevMockProfileFields? devMockProfileFieldsForToken(String? token) {
  final role = devMockRoleFromBearerToken(token);
  if (role == null) return null;
  final email = switch (role) {
    'OWNER' => 'owner@dev.local',
    'STAFF' => 'staff@dev.local',
    'CUSTOMER' => 'client@dev.local',
    _ => 'dev@local',
  };
  return DevMockProfileFields(
    role: role,
    email: email,
    points: 100,
    rank: 'Podgląd',
  );
}

/// Fikcyjne konta dla [AppConfig.useDevMockAuth] — zsynchronizowane z API (`AUTH_DEV_MOCK`)
/// i [prisma/seed.js] (UUID + domyślne e-maile w profilu), gdy backend jest włączony.
/// Token Bearer: `dev-mock:OWNER` | `dev-mock:STAFF` | `dev-mock:CUSTOMER`.
///
/// Zwraca token lub null, jeśli para login/hasło nie pasuje.
String? resolveDevMockBearerToken(String loginRaw, String passwordRaw) {
  final login = loginRaw.trim().toLowerCase();
  final pass = passwordRaw.trim();

  const ownerLogins = <String>{
    'admin',
    'owner',
    'admin@dev.local',
    'owner@dev.local',
  };
  if (pass == 'admin' && ownerLogins.contains(login)) {
    return '${kDevMockTokenPrefix}OWNER';
  }

  const staffLogins = <String>{
    'user',
    'staff',
    'user@dev.local',
    'staff@dev.local',
  };
  if ((pass == 'user' || pass == 'staff') && staffLogins.contains(login)) {
    return '${kDevMockTokenPrefix}STAFF';
  }

  const customerLogins = <String>{
    'client',
    'customer',
    'client@dev.local',
    'customer@dev.local',
  };
  if ((pass == 'client' || pass == 'customer') &&
      customerLogins.contains(login)) {
    return '${kDevMockTokenPrefix}CUSTOMER';
  }

  return null;
}

/// Krótki opis na ekranie logowania (dev-mock).
const String kDevMockAccountsHint = 'OWNER: admin/admin, owner/admin, admin@dev.local/admin\n'
    'STAFF: user/user, staff/staff, staff@dev.local/staff\n'
    'CUSTOMER: client/client, customer/customer, client@dev.local/client\n'
    'Podgląd bez logowania (localhost): dopisz ?previewAs=OWNER lub STAFF lub CUSTOMER do adresu URL.';
