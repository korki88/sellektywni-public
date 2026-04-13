-- CreateEnum
DO $$ BEGIN
  CREATE TYPE "PaymentProvider" AS ENUM ('PRZELEWY24', 'BANK_TRANSFER_MOCK', 'CASH_ON_DELIVERY');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- CreateEnum
DO $$ BEGIN
  CREATE TYPE "PaymentStatus" AS ENUM ('PENDING', 'PAID', 'FAILED', 'CANCELED', 'COD_PENDING');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- AlterTable
ALTER TABLE "customer_orders"
ADD COLUMN IF NOT EXISTS "payment_provider" "PaymentProvider" NOT NULL DEFAULT 'PRZELEWY24',
ADD COLUMN IF NOT EXISTS "payment_status" "PaymentStatus" NOT NULL DEFAULT 'PENDING',
ADD COLUMN IF NOT EXISTS "payment_reference" TEXT,
ADD COLUMN IF NOT EXISTS "payment_session_url" TEXT,
ADD COLUMN IF NOT EXISTS "payment_bank_account" TEXT,
ADD COLUMN IF NOT EXISTS "payment_details" JSONB NOT NULL DEFAULT '{}'::jsonb;

-- Backfill provider/status for existing rows
UPDATE "customer_orders"
SET "payment_provider" = CASE
  WHEN "payment_method" = 'BANK_TRANSFER' THEN 'BANK_TRANSFER_MOCK'::"PaymentProvider"
  WHEN "payment_method" = 'CASH_ON_DELIVERY' THEN 'CASH_ON_DELIVERY'::"PaymentProvider"
  ELSE 'PRZELEWY24'::"PaymentProvider"
END;

UPDATE "customer_orders"
SET "payment_status" = CASE
  WHEN "payment_method" = 'CASH_ON_DELIVERY' THEN 'COD_PENDING'::"PaymentStatus"
  ELSE 'PENDING'::"PaymentStatus"
END;
