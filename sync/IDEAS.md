# Pomysły na jeszcze lepszą synchronizację (opcjonalnie)

- **GitHub Actions** — job `npm ci && npm run build && prisma validate` na każdym PR.
- **Sekrety zespołu** — 1Password / GitHub Environments zamiast plików `.env` w czacie.
- **Devcontainer** — `.devcontainer` z Dockerem + Node + rozszerzeniami (jednolity setup VS Code / Cursor).
- **Ignorowanie `www/app`** — jeśli repo puchnie od buildów Flutter; wtedy obowiązkowy `npm run rerun` na każdej maszynie (zapisać w `WORKLOG.md`).
- **Automatyczny wpis WORKLOG** — hook git `post-commit` dopisujący hash (wymaga ostrożności przy merge).
