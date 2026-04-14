# SELLEKTYWNI.PL — Technical Report

Data raportu: 2026-04-14 (aktualizacja po wdrożeniu Profit Guard Automation)  
Zakres: Sprint Stabilizacyjny (Linting, AuditLog, RBAC) + wdrożenia AI (Profit Guard: UI + Cron + PUSH).

## 1) Code Quality & Build

### `npm run lint:ci` (backend)

- Status: **PASS**
- Wynik: **0 błędów**

### Buildy

- NestJS (`npm run build`): **PASS**
- Flutter Web (`flutter build web`): **PASS**
- Flutter Mobile/Android (`flutter build apk --debug`): **PASS**

### Uwagi o ostrzeżeniach

- `flutter analyze` (obszary dashboard/staff) po poprawkach: **PASS**.
- `npm run lint:ci` + `npm run build` po wdrożeniu Profit Guard Automation: **PASS**.
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

### Audit log dla Profit Guard (SYSTEM_AI)

- Generowanie rekomendacji przez agenta AI logowane jest pod `userId = SYSTEM_AI`.
- Akcje OWNER na propozycjach (akceptacja/odrzucenie) pozostają audytowalne z kontekstem zmian.

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

### Owner Dashboard — moduł AI (Profit Guard)

Stan: **zaimplementowane**.

- Wydzielony widok: `mobile/lib/admin_dashboard/widgets/ai_proposals_view.dart`.
- Rekomendacje renderowane jako karty z akcjami:
  - `Zatwierdź`,
  - `Odrzuć`.
- Integracja z API owner/admin:
  - pobieranie propozycji (`/admin/ai/proposals`),
  - ręczne uruchomienie analizy (`/admin/ai/proposals/generate`),
  - odrzucenie propozycji (`/staff/financial-intelligence/proposals/:id/reject`).

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

### AI / automatyzacja finansowa

Stan: **zaimplementowane**.

- `ProfitGuardAiService` analizuje:
  - `stockAge > 30 dni`,
  - `invoiceDueDate < 7 dni`,
  - marżę i ryzyko.
- Automatyczny harmonogram:
  - `@nestjs/schedule` + Cron codziennie o `03:00` (`Europe/Warsaw`).
- Powiadomienia PUSH dla OWNER:
  - wysyłane przy utworzeniu nowej rekomendacji (`Firebase Admin`, topic domyślny: `owner`).
- Konfiguracja środowiskowa:
  - `FIREBASE_SERVICE_ACCOUNT_JSON` lub `FIREBASE_SERVICE_ACCOUNT_BASE64`,
  - `FIREBASE_OWNER_TOPIC`.

---

## 6) Open Items / Nierozwiązane kwestie

1. **UI logowania social**: brak jawnego przycisku OAuth Google w Flutter (backend gotowy, frontend częściowo).
2. **Integracje przewoźników i płatności**:
   - część adapterów działa live-first, ale realne produkcyjne podpięcie zależy od kluczy i endpointów umownych.
3. **Rozbudowa panelu AI**:
   - warto dodać filtry statusów/historyczne rekomendacje i bulk actions (approve/reject).
4. **Hardening notyfikacji PUSH**:
   - dodać telemetry dostarczeń, retry/backoff i dashboard skuteczności.

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
2. Obecnie backend wysyła powiadomienia OWNER dla nowych rekomendacji Profit Guard (topic).
3. Rozszerzyć wysyłki segmentowane (VINTAGE/GOLD/SILVER) dla Hype Maker i kampanii post-accept.
4. Dodać retry/backoff + telemetry wysyłek.

---

## 9) Publiczna analiza kodu / repo

- Publiczny mirror (branch `main-work`):
  - `https://github.com/korki88/sellektywni-public/tree/main-work`

---

## 10) Documentation Status

Ocena po aktualizacji: dokumentacja techniczna ma teraz **solidny baseline operacyjny i architektoniczny**.

Nowo dodane dokumenty:

- `docs/DOCUMENTATION_INDEX.md` - centralny indeks dokumentacji.
- `docs/ARCHITECTURE.md` - architektura systemu i granice modułów.
- `docs/RBAC_AUDIT_GUIDE.md` - zasady RBAC i audytu.
- `docs/DEPLOYMENT_RUNBOOK.md` - checklista i procedury wdrożeniowe.

Dokumenty już istniejące i utrzymane:

- `docs/INTEGRATIONS.md`
- `docs/PROJECT_FRAMEWORK.md`
- `sync/AGENT_COORDINATION.md`
- `sync/WORKLOG.md`

---

## 11) Rekomendacje architektoniczne pod moduły AI (następny sprint)

1. Dodać telemetry pipeline dla AI (`proposal_generated`, `accepted`, `rejected`, `launched`, `conversion`).
2. Ustalić SLA dla `Profit Guard` i `Hype Maker` (częstotliwość, retry, fallback).
3. Rozszerzyć `Owner Dashboard` o historię rekomendacji i KPI skuteczności kampanii.
4. Dodać testy kontraktowe API dla audytu i RBAC.
5. Dodać test e2e dla zadania Cron (03:00) oraz kontrolę idempotencji generowania propozycji.

