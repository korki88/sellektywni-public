# Artefakty tylko lokalne (nie w Git) — jak je odtworzyć

Te elementy **nie powinny** trafiać do repozytorium wraz z sekretami. Po sklonowaniu na inny komputer odtwarzasz je według poniższej listy.

| Artefakt | W `.gitignore`? | Jak odtworzyć |
|----------|-----------------|---------------|
| **`.env`** | tak | `cp .env.example .env` lub `sync/templates/dotenv.example` → `.env`, uzupełnij sekrety ręcznie |
| **`node_modules/`** | tak | `npm install` |
| **`dist/`** (Nest build) | tak | `npm run build` |
| **`mobile/build/`**, **`.dart_tool/`** | tak (w `mobile/`) | `cd mobile && flutter pub get` oraz `flutter build web ...` |
| **Docker volumes** (dane Postgres) | n/a | `npm run dev:up` tworzy wolumeny lokalnie; `npm run dev:reset-db` czyści dane |
| **Cursor / IDE** | `.idea/`, `.vscode/` często ignorowane | Ustawienia osobiste; opcjonalnie skopiuj snippet z `sync/` jeśli dodamy szablony |
| **Klucze SSH / known_hosts** | poza repo | Na nowym PC: `ssh-keygen`, dodać klucz publiczny do GitHub |

## Co jest w repo celowo

- **`www/app/`** — zbudowany Flutter web może być commitowany (ułatwia podgląd bez Fluttera na danej maszynie). Jeśli repo jest duże, można ignorować `www/app/` i zawsze budować lokalnie — wtedy dopisz decyzję do `WORKLOG.md`.

## Sekrety produkcyjne

Przechowuj w menedżerze haseł lub zmiennych CI/CD — **nigdy** w plikach commitowanych do Git.
