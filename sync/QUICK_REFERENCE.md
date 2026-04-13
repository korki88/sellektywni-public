# Ściąga poleceń

```bash
# Zależności + DB + seed (Docker musi działać)
npm install && npm run dev:up && npx prisma migrate deploy && npm run db:seed

# API dev
npm run start:dev

# Tylko Docker stack
npm run dev:up
npm run dev:down

# Prisma
npx prisma studio
npm run db:seed

# Flutter web → www/app (wymaga Flutter)
npm run rerun

# Dopisz wpis do WORKLOG (Node — Windows/macOS/Linux)
npm run sync:log -- "Krótki opis zadania"
```

**URL:** `http://localhost:3000/app/` · API `http://localhost:3000/`

**Dev auth:** `AUTH_DEV_MOCK=true`, token `Bearer dev-mock:OWNER` (po seedzie).
