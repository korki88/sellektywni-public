# Zasady pracy nad repozytorium SELLEKTYWNI.PL

Zasady wynikające z polecenia właściciela projektu oraz ustalenia techniczne.

## Obowiązkowe

1. **Dziennik `sync/WORKLOG.md`**  
   Po każdym **istotnym** poleceniu użytkownika (zadanie zakończone, merge logiki, nowa funkcja) dopisz krótki wpis: data (UTC), co zrobiono, które pliki/obszary dotknęło. Cel: drugi komputer i agent AI widzą kontekst bez historii czatu Cursor.

2. **Gałąź robocza zamiast nadpisywania `main`**  
   Nowe zmiany wypychaj na branch roboczy (np. `main-home` lub `feature/...`). `main` aktualizuj przez PR lub jawny merge, nie przez force-push „na ślepo”.

3. **Sekrety poza Gitem**  
   Nie commituj pliku `.env` z prawdziwymi kluczami. W repo zostaje `.env.example` oraz `sync/templates/dotenv.example` (kopia referencyjna). Lokalnie: `cp .env.example .env` i uzupełnij.

4. **Pakiet `sync/` w repozytorium**  
   Dokumentacja synchronizacji, szablony i skrypty pomocnicze są częścią projektu i **mają być commitowane** razem ze zmianami kodu, które wpływają na setup.

5. **Spójność z backendem**  
   Po zmianach w Prisma: migracje w `prisma/migrations/`. Po zmianach env: zaktualizuj `.env.example` i `sync/templates/dotenv.example` jeśli dodajesz nowe klucze.

## Zalecane

6. **Nowy komputer:** wykonaj kolejność z [MACHINE_SETUP.md](MACHINE_SETUP.md) (Docker → migrate → seed → opcjonalnie Flutter web).

7. **Docker Desktop (Windows):** jeśli `docker` nie jest w PATH, dodaj `C:\Program Files\Docker\Docker\resources\bin` albo używaj terminala z Docker Desktop.

8. **Flutter:** build web do `www/app` przez `npm run rerun` (z roota repo) lub ręcznie `flutter build web --base-href=/app/`.

9. **Agent AI:** przed długą sesją na drugim PC przeczytaj [AGENT.md](AGENT.md).

10. **GitHub: repozytorium prywatne**  
    Ustawione jako **private** (nie publiczne). Nadal **nie** commitujemy `node_modules`, prawdziwego `.env`, `dist` itd. — uzasadnienie: [POLICY-private-and-gitignore.md](POLICY-private-and-gitignore.md).

11. **Sekrety między komputerami**  
    Nie commituj plaintext `.env`. Stosuj [SECRETS.md](SECRETS.md): GitHub Encrypted Secrets (CI), opcjonalnie **SOPS + age** dla zaszyfrowanego pliku w repo, lub menedżer haseł.

## Aktualizacja tych zasad

Zmiany w `RULES.md` commituj razem z uzasadnieniem w `WORKLOG.md`.
