/**
 * Ustawia rolę profilu w Postgresie (RBAC).
 * Wymaga: działającej bazy, wygenerowanego klienta Prisma (`npm run prisma:generate`).
 *
 * Użycie (PowerShell):
 *   $env:OWNER_USER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
 *   $env:PROFILE_ROLE="OWNER"   # opcjonalnie: STAFF, CUSTOMER, OWNER (domyślnie OWNER)
 *   $env:OWNER_EMAIL="twoj@email.pl"  # opcjonalnie przy pierwszym utworzeniu wiersza
 *   node scripts/set-profile-role.js
 *
 * UUID użytkownika: Supabase → Authentication → Users → kolumna UID,
 * albo z JWT (`sub`) po zalogowaniu w aplikacji.
 */
require('dotenv').config();

const { PrismaClient, ProfileRole, ProfileRank } = require('@prisma/client');

const prisma = new PrismaClient();

function parseRole(raw) {
  const r = (raw || 'OWNER').toUpperCase();
  if (!Object.prototype.hasOwnProperty.call(ProfileRole, r)) {
    throw new Error(
      `Nieprawidłowa PROFILE_ROLE="${raw}". Dozwolone: OWNER, STAFF, CUSTOMER`,
    );
  }
  return ProfileRole[r];
}

async function main() {
  const userId = process.env.OWNER_USER_ID || process.env.PROFILE_USER_ID;
  if (!userId || !/^[0-9a-f-]{36}$/i.test(userId.trim())) {
    console.error(
      'Ustaw zmienną OWNER_USER_ID (lub PROFILE_USER_ID) na poprawny UUID użytkownika Supabase.',
    );
    process.exit(1);
  }

  const role = parseRole(process.env.PROFILE_ROLE);
  const email = process.env.OWNER_EMAIL || process.env.PROFILE_EMAIL || null;

  const row = await prisma.profile.upsert({
    where: { userId: userId.trim() },
    create: {
      userId: userId.trim(),
      email,
      role,
      points: 0,
      rank: ProfileRank.BRONZE,
    },
    update: {
      role,
      ...(email ? { email } : {}),
    },
  });

  console.log('Zaktualizowano profil:', {
    userId: row.userId,
    email: row.email,
    role: row.role,
  });
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
