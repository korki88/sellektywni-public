/**
 * Profile dev-mock (zsynchronizowane z src/auth/dev-mock.constants.ts).
 * Uruchom: npx prisma db seed
 */
require('dotenv').config();

const { randomUUID } = require('crypto');
const {
  PrismaClient,
  ProfileRole,
  ProfileRank,
  PromoDiscountType,
} = require('@prisma/client');

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
      'manage.cms',
      'manage.support',
      'manage.experiments',
      'manage.gift_cards',
      'manage.catalog',
      'manage.reviews',
    ];
  }
  if (role === ProfileRole.STAFF) {
    return [
      'manage.reservations',
      'manage.customers',
      'manage.orders',
      'manage.dotykacka',
      'manage.cms',
      'manage.support',
      'manage.catalog',
      'manage.reviews',
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
  { id: '13', idDotykacka: 'DOTY-13', name: 'Marynarka oversize', price: '699.00', stockQty: 2 },
  { id: '14', idDotykacka: 'DOTY-14', name: 'Sukienka midi satynowa', price: '539.00', stockQty: 3 },
  { id: '15', idDotykacka: 'DOTY-15', name: 'Bluza premium cotton', price: '319.00', stockQty: 5 },
  { id: '16', idDotykacka: 'DOTY-16', name: 'T-shirt heavy jersey', price: '149.00', stockQty: 8 },
  { id: '17', idDotykacka: 'DOTY-17', name: 'Kamizelka pikowana', price: '429.00', stockQty: 4 },
  { id: '18', idDotykacka: 'DOTY-18', name: 'Pasek skorzany klasyczny', price: '189.00', stockQty: 7 },
  { id: '19', idDotykacka: 'DOTY-19', name: 'Portfel skorzany slim', price: '259.00', stockQty: 5 },
  { id: '20', idDotykacka: 'DOTY-20', name: 'Czapka z daszkiem', price: '129.00', stockQty: 9 },
  { id: '21', idDotykacka: 'DOTY-21', name: 'Plaszcz dwurzedowy', price: '1099.00', stockQty: 2 },
  { id: '22', idDotykacka: 'DOTY-22', name: 'Koszula oxford', price: '269.00', stockQty: 6 },
  { id: '23', idDotykacka: 'DOTY-23', name: 'Spodnica plisowana', price: '329.00', stockQty: 4 },
  { id: '24', idDotykacka: 'DOTY-24', name: 'Golf merino', price: '389.00', stockQty: 5 },
  { id: '25', idDotykacka: 'DOTY-25', name: 'Kurtka bomber', price: '649.00', stockQty: 3 },
  { id: '26', idDotykacka: 'DOTY-26', name: 'Jeansy straight fit', price: '299.00', stockQty: 7 },
  { id: '27', idDotykacka: 'DOTY-27', name: 'Sneakers retro', price: '579.00', stockQty: 4 },
  { id: '28', idDotykacka: 'DOTY-28', name: 'Mokasyny skorzane', price: '489.00', stockQty: 3 },
  { id: '29', idDotykacka: 'DOTY-29', name: 'Torba weekendowa', price: '799.00', stockQty: 2 },
  { id: '30', idDotykacka: 'DOTY-30', name: 'Plecak miejski', price: '359.00', stockQty: 6 },
  { id: '31', idDotykacka: 'DOTY-31', name: 'Apaszka jedwabna', price: '219.00', stockQty: 8 },
  { id: '32', idDotykacka: 'DOTY-32', name: 'Rekawiczki skorzane', price: '239.00', stockQty: 5 },
  { id: '33', idDotykacka: 'DOTY-33', name: 'Komplet dresowy premium', price: '499.00', stockQty: 3 },
  { id: '34', idDotykacka: 'DOTY-34', name: 'Bluza z kapturem zip', price: '349.00', stockQty: 4 },
  { id: '35', idDotykacka: 'DOTY-35', name: 'Spodenki bermudy', price: '189.00', stockQty: 6 },
  { id: '36', idDotykacka: 'DOTY-36', name: 'Koszulka polo knit', price: '249.00', stockQty: 5 },
  { id: '37', idDotykacka: 'DOTY-37', name: 'Sztyblety skorzane', price: '689.00', stockQty: 3 },
  { id: '38', idDotykacka: 'DOTY-38', name: 'Kurtka jeansowa', price: '439.00', stockQty: 4 },
  { id: '39', idDotykacka: 'DOTY-39', name: 'Bluzka wiazana', price: '279.00', stockQty: 5 },
  { id: '40', idDotykacka: 'DOTY-40', name: 'Spodnie palazzo', price: '359.00', stockQty: 4 },
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

  const refByEmail = {
    'admin@dev.local': 'DEVREF-OWNER',
    'user@dev.local': 'DEVREF-STAFF',
    'client@dev.local': 'DEVREF-CLIENT',
  };
  for (const r of profileRows) {
    const code = refByEmail[r.email] ?? `DEV${r.userId.replace(/-/g, '').toUpperCase()}`;
    await prisma.profile.update({
      where: { userId: r.userId },
      data: { referralCode: code },
    });
  }

  const giftId = randomUUID();
  await prisma.giftCard.upsert({
    where: { code: 'GIFT-DEV-100' },
    create: {
      id: giftId,
      code: 'GIFT-DEV-100',
      balanceAmount: '100.00',
      initialAmount: '100.00',
      currency: 'PLN',
      active: true,
    },
    update: {
      balanceAmount: '100.00',
      active: true,
    },
  });

  await prisma.cmsPage.upsert({
    where: { slug: 'regulamin' },
    create: {
      slug: 'regulamin',
      title: 'Regulamin sklepu',
      bodyMarkdown:
        '# Regulamin\n\nTo treść demonstracyjna CMS. Edytuj w panelu STAFF (`POST /staff/cms/pages`).',
      published: true,
      seoTitle: 'Regulamin — SELLEKTYWNI',
      seoDescription: 'Regulamin sklepu internetowego.',
    },
    update: { published: true },
  });

  await prisma.cmsPage.upsert({
    where: { slug: 'o-nas' },
    create: {
      slug: 'o-nas',
      title: 'O nas',
      bodyMarkdown:
        '# O nas\n\nSklep z wyselekcjonowaną odzieżą — treść przykładowa.',
      published: true,
      seoTitle: 'O nas — SELLEKTYWNI',
      seoDescription: 'Poznaj SELLEKTYWNI.',
    },
    update: { published: true },
  });

  await prisma.experiment.upsert({
    where: { key: 'checkout_cta' },
    create: {
      id: randomUUID(),
      key: 'checkout_cta',
      active: true,
      variants: ['control', 'emphasize_free_shipping'],
    },
    update: { active: true },
  });

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

  console.log(
    'Seed: profile + referral + gift GIFT-DEV-100 + CMS + eksperyment + WELCOME10 OK.',
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
