/**
 * Profile dev-mock (zsynchronizowane z src/auth/dev-mock.constants.ts).
 * Uruchom: npx prisma db seed
 */
require('dotenv').config();

const { PrismaClient, ProfileRole, ProfileRank } = require('@prisma/client');

const prisma = new PrismaClient();

const rows = [
  {
    userId: '00000000-0000-4000-8000-000000000001',
    email: 'admin@dev.local',
    role: ProfileRole.OWNER,
  },
  {
    userId: '00000000-0000-4000-8000-000000000002',
    email: 'user@dev.local',
    role: ProfileRole.STAFF,
  },
  {
    userId: '00000000-0000-4000-8000-000000000003',
    email: 'client@dev.local',
    role: ProfileRole.CUSTOMER,
  },
];

async function main() {
  for (const r of rows) {
    await prisma.profile.upsert({
      where: { userId: r.userId },
      create: {
        userId: r.userId,
        email: r.email,
        role: r.role,
        points: 0,
        rank: ProfileRank.BRONZE,
      },
      update: {
        email: r.email,
        role: r.role,
      },
    });
  }
  console.log('Seed: profile dev-mock (OWNER, STAFF, CUSTOMER) OK.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
