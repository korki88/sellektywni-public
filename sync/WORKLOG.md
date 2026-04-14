# WORKLOG — dziennik prac (repozytorium)

**Konwencja:** Po zakończeniu zadania użytkownika dopisz **nową sekcję** na górze (pod tym nagłówkiem), z datą UTC i 2–5 punktami: co, gdzie w kodzie, uwagi dla kolejnej maszyny.

Skrypt dopisania (opcjonalnie):

- Wszystkie OS: `npm run sync:log -- "treść wpisu"`
- Windows: `sync/scripts/append-worklog.ps1 -Message "..."`  
- Unix: `sync/scripts/append-worklog.sh "..."`

---

## 2026-04-14 08:05:39 UTC — [agent:cursor-main-a9f3c2d1] Merge `main` + `main-home` do `mani-merge`

- Utworzono branch **`mani-merge`** z `main` i wykonano merge `origin/main-home` bez nadpisywania `main` (backup obu wersji zachowany: `main`, `main-home`).
- Zweryfikowano kompilację po scaleniu: `npm install`, `prisma generate` (lock Windows/EPERM przy rename query engine), finalnie `npm run build` przechodzi poprawnie.
- Flutter po merge: `flutter analyze` zgłasza tylko informacje (deprecated `dart:html`, `prefer_const`), bez błędów blokujących runtime.
- Zaktualizowano `sync/AGENT_COORDINATION.md` o nowy `AGENT_ID` i domyślny branch push = `main`, zgodnie z polityką tego stanowiska.

## 2026-04-14 — E-commerce: merchandising, staff, opinie, WWW (`www/app`)

- **API / Prisma:** `customerNote`, `OrderStaffNote`, `Product.subtitle` / `isFeatured`; anulowanie zamówień (nieopłacone); endpointy `staff/orders/:id`, `staff/orders/:id/notes`, `staff/reviews`; uprawnienia `manage.catalog`, `manage.reviews`.
- **Flutter:** konto (uwagi do zamówienia, anuluj), koszyk (uwagi), strona główna „Polecane”, panel STAFF (opinie, merchandising w kolejce, notatki do zamówień). Statyczny podgląd: `npm run rerun` → `www/app/`.
- **Sync:** ten wpis + aktualny `sync/`; gałąź **`main-home`** (pisownia „mani-home” = to samo co `main-home`).

## 2026-04-13 — Sekrety: SECRETS.md, CI, SOPS/age, katalog secrets/

- Dodano **`sync/SECRETS.md`** — GitHub Encrypted Secrets, workflow **SOPS + age**, menedżery haseł; bez commitu plaintext `.env`.
- **`.github/workflows/ci.yml`** — `npm ci`, `prisma generate`, `npm run build` (bez sekretów).
- **`secrets/.gitkeep`** — miejsce na przyszły `secrets.env.sops` (zaszyfrowany); szablon **`sync/templates/sops-age-recipients.txt.example`**.
- **`.gitignore`** — wzorce `age.key` / `*.age.key` dla kluczy prywatnych age.

## 2026-04-13 — GitHub: repo PRIVATE + polityka `.gitignore`

- **`gh repo edit korki88/sellektywni --visibility private`** — repozytorium jest **prywatne**.
- **Nie commitowano** masowo plików z `.gitignore` (`node_modules`, `.env`, `dist` itd.) — uzasadnienie bezpieczeństwa i rozmiaru: [POLICY-private-and-gitignore.md](POLICY-private-and-gitignore.md).

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

## 2026-04-13 18:59:24 UTC (auto)

- Reguła dedukcji kroków (Cursor + sync/RULES); ESLint naprawiony; npm run lint:ci; CI z lintem; scalarToString (Orlen, shipping, P24); void bootstrap; listProviders sync

## 2026-04-13 19:08:08 UTC (auto)

- [agent:cursor-sellekt-7f3a91c2] API /staff/analytics/summary + low-stock; filtr GET /staff/orders?status=; GET /order/my-orders/:id; Flutter: statystyki na żywo, filtr zamówień, HelpScreen + kontakt; sync/AGENT_COORDINATION.md + reguła Cursor

## 2026-04-13 19:12:32 UTC (auto)

- [agent:cursor-sellekt-7f3a91c2] Rynek PL: MarketService, GET /config/market, SHOP_* w .env; Flutter ShopMarketHolder; walidacja krajów
