# Repozytorium prywatne + polityka wobec `.gitignore`

## Status GitHub (2026-04-13)

Repozytorium **`korki88/sellektywni`** zostało ustawione jako **PRIVATE** (`gh repo edit --visibility private`).

## Prośba: „pushuj wszystko z .gitignore”

**Nie wykonujemy masowego commitu wszystkich ignorowanych plików**, nawet przy prywatnym repo:

| Wzorzec `.gitignore` | Dlaczego nie commitujemy |
|----------------------|---------------------------|
| **`node_modules/`** | Rozmiar setek MB, konflikty platform (Windows/macOS/Linux), źródło prawdy to `package-lock.json` + `npm ci` / `npm install`. |
| **`.env`** | Ryzyko wycieku sekretów (backup, fork, logi CI). Nawet prywatne repo bywa udostępniane. Szablon: `.env.example` + lokalna kopia. |
| **`dist/`** | Artefakt buildu — odtwarzalny przez `npm run build`; commit zwiększa szum w diffach. |
| **`coverage/`**, **`*.log`** | Tymczasowe / generowane. |
| **`.idea/`**, **`.vscode/`** | Ustawienia osobiste IDE; ewentualnie współdzielone szablony w `sync/templates/`. |

### Co robić zamiast tego

1. **Zależności:** `npm install` na każdej maszynie.
2. **Środowisko:** `cp .env.example .env` (lub `sync/templates/dotenv.example`).
3. **Build:** `npm run build`; Flutter WWW: `npm run rerun` lub build ręczny do `www/app`.
4. **Sekrety zespołu poza Gitem:** menedżer haseł, GitHub Secrets (CI), 1Password — jeśli kiedyś potrzebne.

### Odwołanie zasady

Gdy właściciel **odwoła** żądanie „commituj ignorowane”, ta polityka pozostaje jako bezpieczny domyślny standard; można wtedy zaktualizować `RULES.md`.
