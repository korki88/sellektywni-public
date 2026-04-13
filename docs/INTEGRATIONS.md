# Integracje zewnętrzne — SELLEKTYWNI

Ten dokument opisuje, **co jest wymagane**, **co opcjonalne**, oraz **gdzie się zarejestrować** i jakie klucze wkleić do `.env` / builda Fluttera.

---

## 1. PostgreSQL + Prisma (wymagane do API)

| Zmienna | Opis |
|--------|------|
| `DATABASE_URL` | Connection string Postgresa (lokalnie lub hostowany: Neon, Supabase DB, itd.). |

**Ty:** utwórz bazę, skopiuj `.env.example` → `.env`, ustaw `DATABASE_URL`, uruchom migracje:

```bash
npm install
npm run prisma:migrate
```

---

## 0. Local-first stack (zalecane na start)

Repo zawiera gotowy stack deweloperski uruchamiany lokalnie przez Docker:

- `postgres` (`localhost:5432`) - baza aplikacji (Prisma),
- `redis` (`localhost:6379`) - cache/kolejki/rate-limiting pod obecne i przyszle funkcje,
- `minio` (`localhost:9000`, panel `localhost:9001`) - lokalny zamiennik S3,
- `mailpit` (UI `localhost:8025`, SMTP `localhost:1025`) - lokalny mailbox do testow.

Szybki start:

```bash
npm run dev:bootstrap
```

To polecenie:
1. stawia kontenery lokalne,
2. uruchamia migracje Prisma,
3. seeduje przykladowe dane (profile + produkty).

Pozostale komendy:

```bash
npm run dev:up
npm run dev:down
npm run dev:logs
npm run dev:reset-db
```

Po seedzie dostajesz dane pod obecne funkcje panelu i sklepu:
- profile: OWNER / STAFF / CUSTOMER,
- produkty w statusach `AVAILABLE`, `PENDING_APPROVAL`, `SOLD` (do testu flow zamowien i panelu staff).

---

## 1b. Tryb deweloperski bez Supabase (`AUTH_DEV_MOCK`)

Gdy **jeszcze nie integrujesz** zewnętrznych dostawców, możesz uruchomić API i Fluttera z **fikcyjnymi kontami**. Sklep jest dostępny także **jako gość**; logowanie (np. z zakładki „Konto”) przełącza na panel OWNER/STAFF lub konto klienta.

| Warstwa | Ustawienie |
|---------|------------|
| **NestJS `.env`** | `AUTH_DEV_MOCK=true` — akceptuje nagłówek `Authorization: Bearer dev-mock:OWNER` (albo `STAFF`, `CUSTOMER`). `SUPABASE_JWT_SECRET` może być puste w tym trybie (tylko lokalnie). |
| **Baza** | `npm run db:seed` — tworzy 3 profile o stałych UUID (OWNER / STAFF / CUSTOMER). **Wymagane przed logowaniem mock**, inaczej `/auth/profile/ensure` utworzy profil jako CUSTOMER. |
| **Flutter build** | Opcjonalnie `--dart-define=USE_DEV_MOCK_AUTH=true`. Na **localhost / 127.0.0.1** tryb dev-mock włącza się **automatycznie**, jeśli w buildzie **nie** ma `SUPABASE_URL` + `SUPABASE_ANON_KEY` (typowy `flutter build web` do `www`). Przy zbudowanym Supabase: dopisz `?devMock=1` w URL. |
| **Adres API** | Domyślnie `http://<ten_sam_host_co_strona>:3000` (np. `127.0.0.1:3000` gdy strona jest pod `127.0.0.1`). |

**Logowanie w aplikacji (dev-mock)** — pełna lista w `mobile/lib/config/dev_mock_accounts.dart` (funkcja `resolveDevMockBearerToken`):

| Rola | Przykładowe loginy | Hasła |
|------|-------------------|--------|
| **OWNER** | `admin`, `owner`, `admin@dev.local`, `owner@dev.local` | `admin` |
| **STAFF** | `user`, `staff`, `user@dev.local`, `staff@dev.local` | `user` lub `staff` |
| **CUSTOMER** | `client`, `customer`, `client@dev.local`, `customer@dev.local` | `client` lub `customer` |

Najkrócej: `admin/admin` · `user/user` · `client/client`.

**Nigdy nie włączaj `AUTH_DEV_MOCK` na produkcji.**

---

## 2. Supabase Auth (wymagane do logowania w aplikacji i chronionych endpointów API)

Backend weryfikuje JWT użytkownika przy użyciu **tego samego sekretu**, którego używa Supabase do podpisywania tokenów.

| Gdzie | Zmienna / ustawienie |
|-------|----------------------|
| **NestJS (`.env`)** | `SUPABASE_JWT_SECRET` — w panelu Supabase: **Project Settings → API → JWT Secret** (nie mylić z *anon key* ani *service role*). |
| **Flutter Web (build)** | `SUPABASE_URL` — **Project Settings → API → Project URL** |
| | `SUPABASE_ANON_KEY` — **Project Settings → API → anon public** |
| | `API_BASE_URL` — adres Twojego API Nest, np. `http://localhost:3000` |

**Ty:**

1. Załóż darmowy projekt na [supabase.com](https://supabase.com) (konto e-mail / GitHub).
2. Włącz dostawców logowania (**Authentication → Providers**), np. e-mail, Google — zgodnie z potrzebami.
3. Skopiuj **JWT Secret**, **URL** i **anon key** do `.env` (backend) oraz przekaż `dart-define` przy buildzie Flutter (patrz komentarze w `.env.example`).

Bez `SUPABASE_JWT_SECRET` endpointy z middleware JWT zwrócą błąd konfiguracji / 401 — **wyjątek:** gdy `AUTH_DEV_MOCK=true` i używasz tokenów `dev-mock:*` (tylko development).

---

## 3. Dotykačka (opcjonalne)

Integracja z chmurą Dotykačka służy m.in. do **weryfikacji produktu przy składaniu zamówienia** — jeśli nie skonfigurujesz kluczy, API i tak działa, tylko pomija zapytanie do chmury (log „brak CLOUD_ID / ACCESS_TOKEN”).

| Zmienna | Opis |
|---------|------|
| `DOTYKACKA_BASE_URL` | Domyślnie `https://api.dotykacka.cz/v2` |
| `DOTYKACKA_CLOUD_ID` | ID chmury w Dotykačka |
| `DOTYKACKA_ACCESS_TOKEN` | Token API (wg [dokumentacji](https://docs.api.dotykacka.cz/)) |

**Ty:** tylko jeśli używasz Dotykačka w sklepie — rejestracja / dostęp po stronie producenta usługi.

### Rezerwacje magazynowe (workflow)

- Dodanie produktu do koszyka rezerwuje stan (`IN_CART`) i od razu wpływa na dostępność w ofercie.
- Gdy `stock_qty == reserved_qty`, produkt pozostaje widoczny, ale nie można dodać kolejnej sztuki (`RESERVED`).
- Po `Kupuję` koszyk przechodzi do kolejki akceptacji (`PENDING`) z agregacją ilości sztuk.
- Akceptacja staff: odejmuje ilość od magazynu; odrzucenie: zwalnia rezerwację.
- Gdy stan spadnie do `0`, produkt znika z publicznej oferty (`GET /products` filtruje `stockQty > 0`).

### Symulator Dotykačka (dev)

Przy `AUTH_DEV_MOCK=true` dostępny jest prosty symulator stanów magazynowych:

- API:
  - `GET /dotykacka/dev/stock` - lista nadpisanych stanów,
  - `PATCH /dotykacka/dev/stock` - ustawienie `idDotykacka` + `stockQty`.
- UI:
  - panel admina -> zakładka **Dotykačka DEV** (OWNER/STAFF),
  - wpisz `idDotykacka` (np. `DOTY-2`) i stan, kliknij `Ustaw`.

To pozwala testować auto-odrzuty i blokady rezerwacji bez realnej chmury Dotykačka.

---

## 4. Powiadomienia admina (opcjonalne)

| Zmienna | Opis |
|---------|------|
| `ADMIN_WEBHOOK_URL` | Opcjonalny URL do `POST` JSON przy zdarzeniach (np. zamówienie do akceptacji). |

---

## 5. Płatności online: Przelewy24 (sandbox / produkcja)

Checkout obsługuje provider `PRZELEWY24` dla metod online (`BLIK`, `CARD_ONLINE`).

| Zmienna | Opis |
|---------|------|
| `P24_SANDBOX_BASE_URL` | Domyślnie `https://sandbox.przelewy24.pl` |
| `P24_MERCHANT_ID` | ID merchanta sandbox/produkcyjnego |
| `P24_POS_ID` | POS ID (jeśli wymagany przez konto) |
| `P24_CRC` | CRC key do podpisu transakcji |

Bez kluczy API działa w trybie **sandbox-simulation** (link sesji + status `PENDING`), co pozwala testować pełny flow paneli i checkoutu lokalnie.

---

## 6. Moduły przewoźników PL (API-ready + dev simulation)

System ma moduł przewoźników pod szybki checkout i personalizację:

- endpointy:
  - `GET /shipping/providers` - dostępni przewoźnicy i capabilities,
  - `GET /shipping/points/inpost` - punkty odbioru (filtrowanie po kodzie/city),
  - `GET /shipping/estimate` - wycena dostawy.
- checkout:
  - `GET /order/checkout/options` zwraca `shippingProviders` i `suggestedInpostPoints` bazujące na domyślnych/ostatnich danych klienta.
- panel OWNER/STAFF:
  - zakładka **Dostawy** z podglądem providerów i sugerowanych punktów.

Klucze produkcyjne (opcjonalnie, pod adaptery API):

| Zmienna | Opis |
|---------|------|
| `INPOST_API_KEY`, `INPOST_ORG_ID` | InPost |
| `DHL_API_KEY` | DHL eCommerce |
| `DPD_API_KEY` | DPD |
| `POCZTA_POLSKA_API_KEY` | Poczta Polska |

---

## 7. Firebase Cloud Messaging (Flutter — opcjonalne)

Aplikacja mobilna inicjalizuje Firebase do pushy; przy braku konfiguracji loguje ostrzeżenie i działa dalej. **Do podstawowego logowania i panelu nie jest wymagane.**

---

## Konto administratora (OWNER)

Rola **nie** powstaje sama — nowi użytkownicy dostają w bazie `CUSTOMER` (`profiles.service`).

**Procedura:**

1. Zarejestruj się / zaloguj w aplikacji (Supabase), żeby powstał użytkownik w **Authentication** i (po `POST /auth/profile/ensure`) profil w tabeli `profiles`.
2. Skopiuj **UUID** użytkownika: Supabase → **Authentication → Users** (pole *User UID*) — to ten sam identyfikator co `sub` w JWT.
3. Na serwerze z ustawionym `DATABASE_URL` uruchom:

```powershell
cd ścieżka\do\SELLEKTYWNI.PL
$env:OWNER_USER_ID="TWOJ-UUID-Z-SUPABASE"
npm run db:set-role
```

Opcjonalnie: `$env:PROFILE_ROLE="OWNER"` (domyślnie i tak OWNER), `$env:OWNER_EMAIL="..."` przy pierwszym tworzeniu wiersza profilu.

4. Zaloguj się ponownie w aplikacji — `/auth/me` zwróci `role: OWNER`; panel administracyjny i `GET /admin/ping` będą dostępne z JWT tego użytkownika.

---

## Skrót: minimalny zestaw do developmentu

| Składnik | Wymagane? |
|----------|-----------|
| Postgres + `DATABASE_URL` | Tak |
| Supabase projekt + `SUPABASE_JWT_SECRET` + URL + anon key (Flutter) | Tak, jeśli testujesz logowanie i RBAC |
| Dotykačka | Nie |
| Webhook admina | Nie |
| Firebase (mobile push) | Nie |

Szczegóły zmiennych: `.env.example`.

---

## Lokalni zastępcy zewnętrznych dostawców

Docelowe integracje z zewnętrznymi providerami warto rozwijać z zasadą "adapter + local fallback".
W tym repo lokalne odpowiedniki są już przygotowane konfiguracyjnie:

- storage plików: MinIO (S3-compatible),
- e-mail: Mailpit (SMTP + web UI),
- cache/asynchroniczne procesy: Redis.

Dzięki temu nowe funkcje można projektować i testować lokalnie, a na środowiskach zewnętrznych tylko podmieniać konfigurację endpointów/kluczy.
