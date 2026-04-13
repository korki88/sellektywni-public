# WORKLOG — dziennik prac (repozytorium)

**Konwencja:** Po zakończeniu zadania użytkownika dopisz **nową sekcję** na górze (pod tym nagłówkiem), z datą UTC i 2–5 punktami: co, gdzie w kodzie, uwagi dla kolejnej maszyny.

Skrypt dopisania (opcjonalnie):

- Wszystkie OS: `npm run sync:log -- "treść wpisu"`
- Windows: `sync/scripts/append-worklog.ps1 -Message "..."`  
- Unix: `sync/scripts/append-worklog.sh "..."`

---

## 2026-04-13 — Pakiet `sync/` + reguły Cursor + npm scripts

- Dodano katalog **`sync/`** (AGENT, RULES, WORKLOG, MACHINE_SETUP, LOCAL_ARTIFACTS, QUICK_REFERENCE, IDEAS, `templates/dotenv.example`, skrypty bootstrap i append-worklog).
- **`sync/scripts/append-worklog.cjs`** + **`npm run sync:log`** — dopisywanie do WORKLOG na każdym systemie.
- **`npm run sync:bootstrap:win`** / **`sync:bootstrap:unix`** — pełny bootstrap po sklonowaniu (Docker + migrate + seed).
- Zaktualizowano **`README.md`** (opis SELLEKTYWNI + link do `sync/`).
- **`.cursor/rules/sync-worklog.mdc`** — przypomnienie dla agenta AI o WORKLOG i braku sekretów w Git.

## 2026-04-13 — Branch `main-home`, panele Flutter, API, statyczne `/app/`

- Wypchnięto zmiany na branch **`main-home`** (bez nadpisywania `main`): Flutter web pod `/app/` (`src/main.ts`), panele OWNER/STAFF/klient (`admin_dashboard`, `user_account_screen`, `shop_catalog`), pole `shippingMethod` w odpowiedzi staff orders (`staff-orders.service.ts`).
- Lokalny setup: Docker, `prisma migrate`, `db:seed`, `npm run start:dev` — opis wcześniejszy; nie wymaga commitu sekretów.

## 2026-04-13 (wcześniej) — Klonowanie i środowisko lokalne

- Repozytorium: `https://github.com/korki88/sellektywni.git`, gałąź robocza `main-home`.
- Przygotowanie: `npm install`, Docker Compose lokalny, migracje Prisma, seed bazy, `AUTH_DEV_MOCK=true` zgodnie z `.env.example`.

---

*(Starsze wpisy — skrót; szczegóły w historii commitów Git.)*
