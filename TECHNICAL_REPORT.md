# SELLEKTYWNI.PL — Technical Report

Data raportu: 2026-04-14  
Zakres: Sprint Stabilizacyjny (Linting, AuditLog, RBAC) + gotowość pod moduły AI.

## 1) Code Quality & Build

### `npm run lint:ci` (backend)

- Status: **PASS**
- Wynik: **0 błędów**

### Buildy

- NestJS (`npm run build`): **PASS**
- Flutter Web (`flutter build web`): **PASS**
- Flutter Mobile/Android (`flutter build apk --debug`): **PASS**

### Uwagi o ostrzeżeniach

- `flutter analyze` zwraca **9 informacji** (nie krytyczne, nie blokują buildów), m.in.:
  - `deprecated_member_use` dla `dart:html` w plikach web-helpers,
  - `prefer_const_constructors`,
  - `dangling_library_doc_comments`.
- Brak ostrzeżeń krytycznych blokujących uruchomienie lub publikację builda.

---

## 2) Identity & Security (RBAC)

### Struktura roli w bazie i kodzie

- Enum w Prisma: `ProfileRole`:
  - `CUSTOMER`
  - `STAFF`
  - `OWNER`
- Guard (`RolesGuard`) stosuje hierarchię:
  - `CUSTOMER = 0`, `STAFF = 1`, `OWNER = 2`
- Dodatkowo wspierane są:
  - role dokładne (`@Roles(...)`),
  - minimalna rola (`@MinimumRole(...)`).

### Ochrona endpointów `/admin` i `/staff`

- `/admin`:
  - kontroler ma `@UseGuards(RolesGuard)` oraz `@MinimumRole(ProfileRole.OWNER)`.
- `/staff/*`:
  - kontrolery staff mają `@UseGuards(RolesGuard)` i role `STAFF/OWNER`,
  - część endpointów dodatkowo ma granicę `OWNER` (np. dziennik audytu).
- Wniosek: ochrona RBAC dla ścieżek administracyjnych działa i jest spójnie nakładana.

### Metody logowania (Social Auth) — Supabase

Stan potwierdzony w kodzie:

- **Email/hasło**:
  - logowanie: `signInWithPassword`,
  - rejestracja: `signUp`.
- **Google (social)**:
  - backend ma dedykowany flow bootstrap (`/auth/profile/bootstrap-google`) oraz walidację sesji Google w profilu.
  - klient Flutter obecnie nie wystawia dedykowanego przycisku OAuth Google (login UI jest email/password + dev-mock).

Wniosek: warstwa backend jest gotowa pod Google social flow; UI wymaga osobnego kroku, jeśli ma być pełny OAuth button.

---

## 3) Audit Log Implementation

### Model `AuditLog` (Prisma)

Model zawiera:

- `id` (UUID, PK),
- `userId`,
- `userEmail`,
- `action`,
- `resourceType`,
- `resourceId`,
- `oldValue` (JSON, opcjonalne),
- `newValue` (JSON, opcjonalne),
- `ipAddress` (opcjonalne),
- `createdAt` (`now()`).

Dodatkowo indeksy pod wydajny odczyt po użytkowniku, akcji, zasobie i czasie.

### Co jest logowane automatycznie

- Globalny interceptor audytu zapisuje log dla endpointów z rolami `STAFF`/`OWNER`.
- Dla endpointów bez `@AuditAction` używana jest domyślna akcja HTTP (`METHOD + route`).
- Automatyczny interceptor wzbogaca wpis o:
  - `resourceType` (wyliczenie z trasy),
  - `resourceId` (params/body),
  - `ipAddress`.

### Co jest logowane ręcznie (z `oldValue/newValue`)

Krytyczne akcje biznesowe mają logowanie manualne:

- zmiana statusu zamówienia,
- zmiana statusu płatności zamówienia,
- zmiana punktów/rangi klienta,
- akceptacja rekomendacji cenowej AI.

To zapewnia pełny diff operacyjny (stan przed/po).

### Owner Dashboard — UI logów

- Sekcja `Dziennik aktywności` dostępna tylko dla OWNER.
- Działa:
  - filtrowanie tekstowe (email, akcja, resourceType),
  - szybkie filtry (`Wszystkie`, `Tylko Błędy`, `Tylko Sprzedaż`, `Tylko Lojalność`),
  - kolorowanie semantyczne akcji,
  - kliknięcie w wpis i podgląd JSON `oldValue/newValue`,
  - responsywność: tabela desktop, karty na mobile.

---

## 4) Interface Architecture

### Staff Sidebar (Overlay)

Stan: **zaimplementowane**.

- Jest osobny entrypoint overlay (`overlayMain` / `runStaffOverlayApp`).
- Android manifest zawiera wymagane uprawnienia:
  - `SYSTEM_ALERT_WINDOW`,
  - `FOREGROUND_SERVICE`,
  - `FOREGROUND_SERVICE_SPECIAL_USE`,
  - zarejestrowany `OverlayService`.
- Launcher overlay sprawdza i prosi o permission runtime.

### Spójność wejść Flutter dla ról

- `SellektywniApp`:
  - OWNER/STAFF (po autoryzacji) trafiają do dashboardu administracyjnego,
  - CUSTOMER/gość trafia do sklepu (`MainStore`).
- Architektura wejść jest spójna z modelem ról.

---

## 5) Database Schema (State)

### `Product` — pola finansowe

Stan: **obecne w schemacie**:

- `purchasePriceNet`,
- `vatRate`,
- `marginTarget`,
- `supplierId` (+ relacja do `Supplier`).

To umożliwia dalszy rozwój analiz marżowych oraz modułów AI.

### Prisma version

- `prisma`: `^6.19.3`
- `@prisma/client`: `^6.19.3`

Potwierdzenie: projekt pozostaje na Prisma 6.x, bez migracji do v7.

---

## 6) Open Items / Nierozwiązane kwestie

1. **Flutter analyze** ma 9 niekrytycznych infos (warto zamknąć przed release hardening).
2. **UI logowania social**: brak jawnego przycisku OAuth Google w Flutter (backend gotowy, frontend częściowo).
3. **Integracje przewoźników i płatności**:
   - część adapterów działa live-first, ale realne produkcyjne podpięcie zależy od kluczy i endpointów umownych.
4. **Repo visibility automatycznie**:
   - w tym środowisku brak `gh` CLI, więc nie da się automatycznie przełączyć repo na publiczne z poziomu agenta.
5. **Duży plik UI**:
   - `mobile/lib/admin_dashboard/admin_dashboard.dart` jest nadal bardzo duży (wart refaktor do mniejszych widgetów/feature files).

---

## 7) `sync/` — dlaczego istnieje i jak działa (2 komputery, wielu agentów)

Folder `sync/` jest kluczowy dla pracy na dwóch komputerach i równoległej pracy agentów:

- `sync/AGENT_COORDINATION.md`:
  - definiuje `AGENT_ID`,
  - zasady branchowania i rozdziału pracy, by agenci się nie nadpisywali.
- `sync/WORKLOG.md`:
  - dziennik zmian i decyzji architektonicznych,
  - szybki transfer kontekstu między maszynami.
- `sync/MACHINE_SETUP.md`, `sync/QUICK_REFERENCE.md`:
  - standaryzacja odtworzenia środowiska.

Rekomendowany workflow dla Twojego modelu pracy (2 komputery):

1. Na końcu sesji: commit + push + wpis do `sync/WORKLOG.md`.
2. Na drugim komputerze: pull + lektura najnowszego wpisu `WORKLOG`.
3. Każdy agent pracuje z własnym `AGENT_ID` i czytelnym branch ownership.

To minimalizuje konflikty i skraca czas odzyskania kontekstu.

---

## 8) Brakujące integracje + instrukcje wdrożenia

### A) Supabase Social OAuth (Google) — pełne domknięcie UI

Kroki:

1. Supabase: `Authentication -> Providers -> Google` (client ID/secret + redirect URL).
2. Flutter: dodać akcję `signInWithOAuth(Provider.google)` w ekranie logowania.
3. Backend: po sesji wywołać bootstrap profilu Google (`/auth/profile/bootstrap-google`).
4. Test: nowy user Google -> profil `CUSTOMER/BRONZE`, poprawny RBAC.

### B) Przelewy24 live

Kroki:

1. Uzupełnić `.env` (`P24_MERCHANT_ID`, `P24_POS_ID`, `P24_CRC`, `P24_URL_RETURN`).
2. Potwierdzić callback/status (`P24_URL_STATUS`) i firewall/SSL.
3. Testy E2E sandbox -> live-register fallback off.
4. Monitoring błędów rejestracji transakcji.

### C) DPD / DHL / Poczta / ORLEN — produkcyjne endpointy

Kroki:

1. Uzupełnić klucze i ścieżki API per provider.
2. Zweryfikować mapowanie payloadów punktów odbioru.
3. Ustawić TTL cache zgodnie z SLA operatora.
4. Dodać smoke testy na `/shipping/points/suggest`.

### D) Firebase PUSH (Hype Maker / segmentacja)

Kroki:

1. Dostarczyć konfigurację Firebase dla Android/iOS/Web.
2. Podpiąć realne wysyłki push (obecnie część flow przygotowuje treści draftów).
3. Dodać retry/backoff + telemetry wysyłek.

---

## 9) Publiczna analiza kodu / repo

- Publiczny mirror (branch `main-work`):
  - `https://github.com/korki88/sellektywni-public/tree/main-work`

---

## 10) Rekomendacje architektoniczne pod moduły AI (następny sprint)

1. Zamknąć 9 info z `flutter analyze` (baseline quality gate).
2. Wydzielić `AdminDashboard` na feature modules (`audit`, `permissions`, `ai`, `marketing`).
3. Dodać telemetry pipeline dla AI (`proposal_generated`, `accepted`, `launched`, `conversion`).
4. Ustalić SLA dla `Profit Guard` i `Hype Maker` (częstotliwość, retry, fallback).
5. Dodać testy kontraktowe API dla audytu i RBAC.

