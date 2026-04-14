# SELLEKTYWNI.PL - RBAC and Audit Guide

## 1. Roles and Permissions

Źródło roli: `ProfileRole` (`CUSTOMER`, `STAFF`, `OWNER`).

Egzekwowanie:

- `RolesGuard` sprawdza:
  - role dokładne (`@Roles(...)`),
  - lub minimum roli (`@MinimumRole(...)`).
- Dodatkowe klucze uprawnień są walidowane przez `assertStaffPermission(...)`.

## 2. Protected Surfaces

- `/admin/*` - OWNER only.
- `/staff/*` - STAFF/OWNER (część endpointów owner-only).
- `/staff/audit-logs` - OWNER only (odczyt dziennika aktywności).

## 3. AuditLog Model

Tabela `audit_logs` przechowuje:

- `userId`, `userEmail`,
- `action`,
- `resourceType`, `resourceId`,
- `oldValue`, `newValue`,
- `ipAddress`,
- `createdAt`.

## 4. Automatic Audit Flow

Globalny interceptor:

1. Wykrywa endpointy oznaczone rolami `STAFF`/`OWNER`.
2. Po sukcesie requestu zapisuje rekord audytu.
3. Uzupełnia domyślnie `resourceType`/`resourceId` na podstawie trasy i payloadu.

## 5. Manual Audit for Critical Actions

Dla operacji wymagających stanu przed/po stosowane jest logowanie jawne:

- zmiana statusu zamówienia,
- zmiana statusu płatności,
- zmiana punktów/rangi klienta,
- akceptacja rekomendacji AI.

## 6. Owner Dashboard: Activity Journal

Sekcja `Dziennik aktywności`:

- dostęp wyłącznie dla OWNER,
- filtry: tekstowe + szybkie kategorie,
- semantyczne kolory akcji,
- modal szczegółów (`oldValue` / `newValue`),
- responsywność: tabela desktop, karty mobile.

## 7. Operational Checklist

Przed wydaniem:

1. Sprawdź `npm run lint:ci` i `npm run build`.
2. Zweryfikuj, że nowe endpointy admina mają:
   - `RolesGuard`,
   - właściwy poziom roli,
   - wpis do audytu (auto lub manual).
3. Potwierdź owner-only read dla dziennika audytu.
