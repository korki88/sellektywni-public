# SELLEKTYWNI.PL - Architecture Overview

## 1. System Topology

- Backend: monolit modulowy `NestJS` (`src/`), API REST.
- Data layer: `PostgreSQL` + `Prisma`.
- Frontend: jeden projekt `Flutter` (`mobile/`) z trzema trybami wejścia:
  - `Owner Dashboard`,
  - `Staff Sidebar` (Android overlay),
  - `Customer App`.
- Public mirror kodu: `https://github.com/korki88/sellektywni-public/tree/main-work`.

## 2. Domain Boundaries (Backend)

Najważniejsze moduły backendowe:

- `auth/` - JWT + profil użytkownika.
- `staff/` - operacje personelu i właściciela.
- `order/` - koszyk, finalizacja, statusy zamówień.
- `product/` - oferta i wyszukiwarka.
- `shipping/` - providerzy i punkty odbioru.
- `audit/` - logowanie operacji administracyjnych.
- `financial-intelligence/` - analiza ryzyka płynności i propozycje AI.
- `marketing-automation/` - drafty marketingowe i automatyzacje po akceptacji AI.
- `notifications/` - powiadomienia administracyjne.

## 3. Access Architecture

RBAC oparty o `ProfileRole`:

- `OWNER` - pełny dostęp.
- `STAFF` - operacje operacyjne (zamówienia, rezerwacje, lojalność, skaner).
- `CUSTOMER` - ścieżka zakupowa.

Egzekwowanie:

- `RolesGuard` + dekoratory `@Roles` / `@MinimumRole`.
- Middleware sesji (`supabase-jwt`, `load-profile`) dla chronionych kontrolerów.

## 4. Key Cross-Cutting Concerns

### 4.1 Auditability

- Globalny interceptor audytu dla endpointów staff/owner.
- Rozszerzony `AuditLog` (kto/co/na czym/stan przed-po/ip/czas).
- Manualne logowanie dla krytycznych mutacji biznesowych.

### 4.2 Modularity and Fault Isolation

- Integracje shipping/płatności działają w modelu live-first + fallback.
- Feature flags `FEATURE_*` pozwalają wyłączać obszary bez wyłączania całej aplikacji.

### 4.3 Financial Safety

- `Product` zawiera pola finansowe (`purchasePriceNet`, `vatRate`, `marginTarget`).
- Moduł AI wspiera decyzje pod płynność (`Profit Guard`) i aktywację promocji (`Hype Maker`).

## 5. Frontend Role Routing

Flow wejścia:

1. `AuthSession` odczytuje token i profil.
2. `SellektywniApp`:
   - OWNER/STAFF -> `AdminDashboard`,
   - CUSTOMER/gość -> `MainStore`.
3. Android overlay uruchamia `Staff Sidebar` przez osobny entrypoint `overlayMain`.

## 6. Dotykačka as Stock Source of Truth

- Dotykačka traktowana jako nadrzędne źródło stanów.
- Rezerwacje online trafiają jako `PENDING_APPROVAL`.
- Akceptacja odbywa się ręcznie z poziomu `Staff Sidebar`.

## 7. Integration Strategy

- Zewnętrzne API: live-first.
- Cache jako optymalizacja, nie źródło prawdy.
- Fallback bez blokowania krytycznego checkoutu.

Szczegóły operacyjne: `docs/INTEGRATIONS.md`.
