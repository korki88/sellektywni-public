-- AlterEnum
ALTER TYPE "CustomerOrderStatus" ADD VALUE IF NOT EXISTS 'PROCESSING';
ALTER TYPE "CustomerOrderStatus" ADD VALUE IF NOT EXISTS 'READY';
ALTER TYPE "CustomerOrderStatus" ADD VALUE IF NOT EXISTS 'COMPLETED';
ALTER TYPE "CustomerOrderStatus" ADD VALUE IF NOT EXISTS 'CANCELED';

-- AlterTable
ALTER TABLE "profiles"
ADD COLUMN "permissions" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

-- Backfill defaults by role
UPDATE "profiles"
SET "permissions" = ARRAY[
  'manage.reservations',
  'manage.customers',
  'manage.orders',
  'manage.dotykacka'
]
WHERE "role" = 'STAFF';

UPDATE "profiles"
SET "permissions" = ARRAY[
  'manage.reservations',
  'manage.customers',
  'manage.orders',
  'manage.dotykacka',
  'manage.permissions',
  'view.analytics'
]
WHERE "role" = 'OWNER';
