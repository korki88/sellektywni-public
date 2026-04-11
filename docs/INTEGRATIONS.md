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

---

## 4. Powiadomienia admina (opcjonalne)

| Zmienna | Opis |
|---------|------|
| `ADMIN_WEBHOOK_URL` | Opcjonalny URL do `POST` JSON przy zdarzeniach (np. zamówienie do akceptacji). |

---

## 5. Firebase Cloud Messaging (Flutter — opcjonalne)

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
