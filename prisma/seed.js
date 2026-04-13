/**
 * Profile dev-mock (zsynchronizowane z src/auth/dev-mock.constants.ts).
 * Uruchom: npx prisma db seed
 */
require('dotenv').config();

const { PrismaClient, ProfileRole, ProfileRank, PromoDiscountType } = require('@prisma/client');

const prisma = new PrismaClient();

const profileRows = [
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

function defaultPermissions(role) {
  if (role === ProfileRole.OWNER) {
    return [
      'manage.reservations',
      'manage.customers',
      'manage.orders',
      'manage.dotykacka',
      'manage.permissions',
      'view.analytics',
    ];
  }
  if (role === ProfileRole.STAFF) {
    return [
      'manage.reservations',
      'manage.customers',
      'manage.orders',
      'manage.dotykacka',
    ];
  }
  return [];
}

const productRows = [
  { id: '1', idDotykacka: 'DOTY-1', name: 'Kaszmirowy sweter', price: '459.00', stockQty: 3 },
  { id: '2', idDotykacka: 'DOTY-2', name: 'Lniana koszula', price: '289.00', stockQty: 2 },
  { id: '3', idDotykacka: 'DOTY-3', name: 'Trencz welniany', price: '899.00', stockQty: 1 },
  {
    id: '4',
    idDotykacka: 'DOTY-4',
    name: 'Spodnie garniturowe',
    price: '349.00',
    stockQty: 4,
  },
  {
    id: '5',
    idDotykacka: 'DOTY-5',
    name: 'Skorzane sneakersy',
    price: '629.00',
    stockQty: 2,
  },
  { id: '6', idDotykacka: 'DOTY-6', name: 'Kozaki na obcasie', price: '519.00', stockQty: 1 },
  { id: '7', idDotykacka: 'DOTY-7', name: 'Loafers zamszowe', price: '449.00', stockQty: 2 },
  { id: '8', idDotykacka: 'DOTY-8', name: 'Buty sportowe', price: '399.00', stockQty: 3 },
  { id: '9', idDotykacka: 'DOTY-9', name: 'Skorzana torba', price: '759.00', stockQty: 1 },
  { id: '10', idDotykacka: 'DOTY-10', name: 'Jedwabny szalik', price: '199.00', stockQty: 5 },
  {
    id: '11',
    idDotykacka: 'DOTY-11',
    name: 'Zegarek minimalistyczny',
    price: '1129.00',
    stockQty: 1,
  },
  {
    id: '12',
    idDotykacka: 'DOTY-12',
    name: 'Okulary przeciwsloneczne',
    price: '429.00',
    stockQty: 2,
  },
];

async function main() {
  for (const r of profileRows) {
    await prisma.profile.upsert({
      where: { userId: r.userId },
      create: {
        userId: r.userId,
        email: r.email,
        role: r.role,
        permissions: defaultPermissions(r.role),
        points: 0,
        rank: ProfileRank.BRONZE,
      },
      update: {
        email: r.email,
        role: r.role,
        permissions: defaultPermissions(r.role),
      },
    });
  }
  for (const p of productRows) {
    await prisma.product.upsert({
      where: { id: p.id },
      create: {
        id: p.id,
        idDotykacka: p.idDotykacka,
        name: p.name,
        price: p.price,
        stockQty: p.stockQty,
        status: 'AVAILABLE',
      },
      update: {
        idDotykacka: p.idDotykacka,
        name: p.name,
        price: p.price,
        stockQty: p.stockQty,
        status: 'AVAILABLE',
      },
    });
  }

  await prisma.promoCode.upsert({
    where: { code: 'WELCOME10' },
    create: {
      code: 'WELCOME10',
      label: 'Powitalny -10% (min. 100 zł)',
      discountType: PromoDiscountType.PERCENT,
      percentOff: 10,
      minOrderAmount: '100.00',
      maxUses: 5000,
      maxUsesPerUser: 1,
      active: true,
    },
    update: {
      label: 'Powitalny -10% (min. 100 zł)',
      discountType: PromoDiscountType.PERCENT,
      percentOff: 10,
      minOrderAmount: '100.00',
      maxUses: 5000,
      maxUsesPerUser: 1,
      active: true,
    },
  });

  console.log('Seed: profile dev-mock (OWNER, STAFF, CUSTOMER) + produkty + kod WELCOME10 OK.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
