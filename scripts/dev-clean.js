/**
 * Czyste środowisko lokalne: Postgres (volume), migracje, seed, flush Redis.
 * Wymaga: Docker Desktop, plik .env z DATABASE_URL.
 */
const { execSync } = require('child_process');
const path = require('path');
const { setTimeout: delay } = require('timers/promises');

const root = path.join(__dirname, '..');

function sh(cmd) {
  // eslint-disable-next-line no-console
  console.log('>', cmd);
  execSync(cmd, { stdio: 'inherit', cwd: root, shell: true, env: process.env });
}

async function waitForPostgres() {
  for (let i = 0; i < 45; i++) {
    try {
      execSync('docker exec sellektywni-postgres pg_isready -U postgres', {
        stdio: 'pipe',
        cwd: root,
      });
      return;
    } catch {
      await delay(2000);
    }
  }
  throw new Error('Timeout: PostgreSQL (sellektywni-postgres) nie odpowiada.');
}

async function main() {
  sh('docker compose -f docker-compose.local.yml down -v');
  sh('docker compose -f docker-compose.local.yml up -d');
  await waitForPostgres();
  sh('npx prisma migrate deploy');
  sh('npm run db:seed');
  try {
    sh('docker exec sellektywni-redis redis-cli FLUSHALL');
  } catch {
    // eslint-disable-next-line no-console
    console.warn('(Redis flush opcjonalny — kontener może nie działać)');
  }
  // eslint-disable-next-line no-console
  console.log('dev:clean zakończone — baza gotowa do testów.');
}

main().catch((e) => {
  // eslint-disable-next-line no-console
  console.error(e);
  process.exit(1);
});
