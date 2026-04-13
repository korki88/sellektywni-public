# Instrukcja dla agenta AI (drugi komputer / nowe środowisko)

Przeczytaj ten plik **przed** większą zmianą w projekcie. Uzupełnia kontekst, którego nie ma w samym kodzie.

## Czym jest ten projekt

- **Backend:** NestJS (`src/`), Node.js, REST API na domyślnym porcie **3000**.
- **Baza:** PostgreSQL przez **Prisma** (`prisma/schema.prisma`, migracje w `prisma/migrations/`).
- **Frontend mobilny / web:** Flutter w `mobile/`. Build produkcyjny WWW kopiowany do **`www/app`** z `--base-href=/app/`.
- **Serwer www:** Nest serwuje statyczne pliki Flutter z `www/app` pod **`/app/`**, przekierowanie **`/` → `/app/`** (`src/main.ts`).
- **Uwierzytelnianie:** Supabase JWT lub tryb dev **`AUTH_DEV_MOCK=true`** z tokenami `Bearer dev-mock:OWNER|STAFF|CUSTOMER` (profile z **`npm run db:seed`**).

## Minimalny zestaw po `git clone`

1. Node **20 LTS** (zalecane; projekt ostrzegał przy Node 18).
2. **`.env`:** skopiuj z **`sync/templates/dotenv.example`** lub `.env.example` w katalogu głównym do **`.env`** w root repo (nie commituj `.env`).
3. **Docker Desktop** — uruchomiony daemon.
4. W katalogu głównym repo:

```bash
npm install
npm run dev:up
npx prisma migrate deploy
npm run db:seed
npm run start:dev
```

5. Przeglądarka: `http://localhost:3000/app/` (UI), API pod tym samym hostem.

## Ważne ścieżki

| Obszar | Ścieżka |
|--------|---------|
| API | `src/**/*.ts` |
| Zamówienia / checkout | `src/order/` |
| Wysyłka | `src/shipping/` |
| Staff | `src/staff/` |
| Flutter — panel admin | `mobile/lib/admin_dashboard/` |
| Etykiety PL (sklep) | `mobile/lib/config/shop_catalog.dart` |
| Konfiguracja dev-mock | `mobile/lib/config/dev_mock_accounts.dart`, `mobile/lib/config/app_config.dart` |
| Docker lokalny | `docker-compose.local.yml` |

## Integracje zewnętrzne

- **Dotykačka** — opcjonalna; bez `DOTYKACKA_CLOUD_ID` używane są stany z bazy; dev: `/dotykacka/dev/stock`.
- **Przelewy24** — opcjonalne klucze `P24_*`; bez nich symulacja sandbox.
- **Kurierzy** — InPost, DPD, DHL, Poczta, ORLEN; przy braku kluczy API — fallback / symulacja (patrz `src/shipping/`).

## Zasady pracy z repo

Obowiązuje **`sync/RULES.md`**: m.in. aktualizacja **`sync/WORKLOG.md`** po zadaniach, brak commitu sekretów, praca na branchach roboczych.

## Gdy coś nie działa na nowym PC

1. `DATABASE_URL` w `.env` zgodny z Dockerem (`localhost:5432`, baza `sellektywni`).
2. `docker ps` — kontenery postgres/redis/minio/mailpit.
3. `npx prisma migrate deploy` — brak błędów.
4. Flutter: `cd mobile && flutter pub get`; WWW: `npm run rerun` (wymaga Flutter w PATH).

## Historia decyzji

Szczegóły zadań użytkownika: **`sync/WORKLOG.md`**.
