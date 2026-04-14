# Sekrety — bezpieczna synchronizacja (bez commitu `.env` w plaintext)

Cel: **drugi komputer** i **CI/CD** bez wrzucania haseł do historii Git w czytelnej postaci.

## Zasady

1. **`.env` w katalogu głównym** — tylko lokalnie, w **`.gitignore`**. Nie commituj.
2. **Szablon bez sekretów** — `.env.example` i `sync/templates/dotenv.example` (commitowane).
3. **Prywatne repo** nie zastępuje ochrony — traktuj jak publiczne pod kątem sekretów w commitach.

---

## 1. GitHub Encrypted Secrets (CI / wdrożenia)

**Ustawienia:** repozytorium → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.

### Sugerowane nazwy (dopasuj do pipeline’u)

| Nazwa sekretu | Zastosowanie |
|---------------|--------------|
| `DATABASE_URL` | Migracje / testy integracyjne w CI (jeśli używasz prawdziwej bazy) |
| `SUPABASE_JWT_SECRET` | Build/test wymagający JWT (rzadko w samym `nest build`) |
| `P24_CRC`, `P24_MERCHANT_ID`, `P24_POS_ID` | Tylko job wdrażający z prawdziwym P24 |
| `INPOST_API_KEY` itd. | Tylko gdy job wywołuje API kurierskie |

W workflow odwołujesz się: `${{ secrets.DATABASE_URL }}` — **nigdy** nie loguj sekretów (`echo`).

### Minimalny CI (bez sekretów do buildu)

Zobacz [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) — `npm ci`, **`npm run lint:ci`**, `prisma generate`, `npm run build` (bez bazy). Gdy dodasz testy z DB, wtedy dodaj **service** Postgres w jobie i **jeden** sekret `DATABASE_URL` tylko dla tego joba.

---

## 2. SOPS + age — zaszyfrowany plik w repozytorium (zespoły)

Narzędzia:

- [SOPS](https://github.com/getsops/sops) — edycja i szyfrowanie plików.
- [age](https://github.com/FiloSottile/age) — nowoczesne klucze (para publiczny/prywatny).

### Instalacja (skrót)

- **Windows:** `winget install FiloSottile.age` oraz pobierz `sops` z [releases SOPS](https://github.com/getsops/sops/releases) albo `choco install sops` / `scoop install sops`.
- **macOS:** `brew install sops age`
- **Linux:** pakiet dystrybucji lub binaria z GitHub.

### Generacja klucza age (raz na osobę)

```bash
age-keygen -o ~/.config/sellektywni/age.key
```

**Plik `age.key` trzymaj poza repo** (menedżer haseł, dysk zaszyfrowany).  
Publiczny fragment (`age1…`) możesz dodać do pliku odbiorców zespołu (commitowany).

### Pierwsze szyfrowanie `.env`

Z katalogu głównego repo (przykład z jednym odbiorcą age):

```bash
export SOPS_AGE_RECIPIENTS_FILE=sync/templates/sops-age-recipients.txt
# plik zawiera jedną linię na klucz publiczny age1...
sops -e .env > secrets/secrets.env.sops
```

Albo edycja „na żywo”:

```bash
sops secrets/secrets.env.sops
```

### Odszyfrowanie na drugim komputerze

```bash
export SOPS_AGE_KEY_FILE=%USERPROFILE%\.config\sellektywni\age.key   # Windows PowerShell: $env:SOPS_AGE_KEY_FILE=...
sops -d secrets/secrets.env.sops > .env
```

**Commituj tylko** `secrets/secrets.env.sops` (zaszyfrowany), **nigdy** `age.key` ani `.env`.

### Szablon odbiorców

Zobacz [`sync/templates/sops-age-recipients.txt.example`](templates/sops-age-recipients.txt.example) — skopiuj do `sync/templates/sops-age-recipients.txt` (lokalnie, **nie commituj** jeśli zawiera tylko klucze prywatne — ten plik to **tylko publiczne** `age1…`).

---

## 3. Menedżer haseł (1Password, Bitwarden, …)

- Sekrety produkcyjne: **Secure Note** z treścią `.env` lub osobne pola.
- Na nowym PC: eksport ręczny do `.env` (nie przez Git).
- Dla zespołu: **SOPS** (powyżej) jest lepszy niż kopiowanie plików mailem.

---

## 4. Co jest w repozytorium po tej zmianie

- [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) — build bez sekretów.
- `sync/templates/sops-age-recipients.txt.example` — przykład listy odbiorców age.
- Katalog `secrets/` z `.gitkeep` — możesz umieścić tu `secrets.env.sops` po pierwszym `sops`.

---

## 5. Checklist nowego developera

1. `git clone` + `cp .env.example .env` (dev lokalny).
2. Opcja A: otrzymać **SOPS** `secrets.env.sops` + **prywatny** klucz age poza Gitem → `sops -d … > .env`.
3. Opcja B: dostać sekrety z **menedżera haseł** zespołu.
4. **Nigdy** nie commituj plaintext `.env`.
