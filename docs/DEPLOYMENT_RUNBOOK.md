# SELLEKTYWNI.PL - Deployment Runbook

## 1. Goal

Runbook opisuje bezpieczne przejście z brancha do wdrożenia oraz kontrolę jakości po wdrożeniu.

## 2. Preconditions

- Node.js zgodny z `package.json` (`>=20.18.0`).
- Dostęp do produkcyjnego `DATABASE_URL`.
- Uzupełnione sekrety (`SUPABASE_*`, płatności, shipping, webhooki opcjonalne).
- Potwierdzony release branch/tag.

## 3. Mandatory Quality Gate

W katalogu głównym:

```bash
npm ci
npm run lint:ci
npm run build
```

W katalogu `mobile/`:

```bash
flutter analyze
flutter build web
flutter build apk --debug
```

Uwaga: informacje z `flutter analyze` nie blokują release, ale powinny być śledzone.

## 4. Database Migration Procedure

```bash
npx prisma migrate deploy
npx prisma generate
```

Jeśli to środowisko inicjalne:

```bash
npm run db:seed
```

## 5. Rollout Steps

1. Deploy backend (`dist/` po `npm run build`).
2. Deploy Flutter Web artefaktów (`mobile/build/web` -> `www/app` jeśli używany ten model).
3. Restart procesów runtime.
4. Smoke test:
   - `/admin/ping` dla OWNER,
   - podstawowe `/staff/*`,
   - checkout i płatności (sandbox/live zgodnie ze środowiskiem).

## 6. Post-Deploy Verification

- AuditLog przyjmuje wpisy dla akcji staff/owner.
- Owner Dashboard pokazuje aktualne wpisy i filtry.
- Staff Sidebar działa na Androidzie (permission overlay + uruchomienie panelu).
- Integracje shipping zwracają co najmniej fallbacki bez błędów krytycznych.

## 7. Rollback Plan

1. Cofnij deploy aplikacji do poprzedniego artefaktu.
2. Jeśli migracja była tylko addytywna, utrzymaj schemat i napraw kod.
3. Jeśli wymagana jest migracja wstecz:
   - przygotuj dedykowany skrypt rollback (manual SQL),
   - wykonaj backup danych przed operacją.

## 8. Multi-machine Sync Discipline

Po każdej sesji wdrożeniowej:

1. Commit i push.
2. Wpis do `sync/WORKLOG.md` (co wdrożono, co sprawdzone, co zostało).
3. Na drugim komputerze: pull + weryfikacja `WORKLOG`.
