#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
echo "[sync/bootstrap] Root: $ROOT"

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "[sync/bootstrap] Created .env from .env.example — edit secrets."
fi

npm install
npm run dev:up
sleep 6
npx prisma migrate deploy
npm run db:seed

echo "[sync/bootstrap] Done. Run: npm run start:dev"
