# Konfiguracja nowej maszyny (od zera)

## Wymagania

| Narzędzie | Uwagi |
|-----------|--------|
| Git | `git clone` repozytorium |
| Node.js | 20.x LTS zalecane |
| npm | Razem z Node |
| Docker Desktop | Windows: włącz integrację WSL2 jeśli prosi instalator |
| (Opcjonalnie) Flutter | Dla `mobile/` i `npm run rerun` — SDK stabilny |

## 1. Klonowanie i branch

```bash
git clone https://github.com/korki88/sellektywni.git
cd sellektywni
git checkout main-home
git pull
```

*(Lub inny branch roboczy ustalony w zespole.)*

## 2. Zmienne środowiskowe

```bash
cp .env.example .env
# albo: cp sync/templates/dotenv.example .env
```

Edytuj `.env` tylko lokalnie. **Nie commituj.**

## 3. Zależności Node i Prisma

```bash
npm install
npx prisma generate
```

## 4. Docker i baza

```bash
npm run dev:up
```

Poczekaj aż Postgres wstanie (~kilka sekund). Potem:

```bash
npx prisma migrate deploy
npm run db:seed
```

## 5. Uruchomienie API

```bash
npm run start:dev
```

## 6. Flutter Web (opcjonalnie)

Jeśli masz Flutter w PATH, z **katalogu głównego repo**:

```bash
npm run rerun
```

Inaczej ręcznie z `mobile/`:

```bash
cd mobile
flutter pub get
flutter build web --release --base-href=/app/
```

Skopiuj zawartość `mobile/build/web/` do `www/app/` (tak jak robi skrypt `rerun`).

## 7. Weryfikacja

- `http://localhost:3000/` → przekierowanie na `/app/`
- `http://localhost:3000/products` → JSON z API
- `http://localhost:3000/app/` — sklep (po buildzie WWW)

## Skrypt jednym ciągiem (Windows PowerShell)

Zobacz `sync/scripts/bootstrap.ps1`.

## GitHub CLI

`gh auth login` — jeśli używasz `gh` (PR, issues). Token wygasa okresowo.
