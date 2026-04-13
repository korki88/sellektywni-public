-- CreateEnum
DO $$ BEGIN
  CREATE TYPE "PaymentMethod" AS ENUM ('BLIK', 'CARD_ONLINE', 'BANK_TRANSFER', 'CASH_ON_DELIVERY');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- CreateEnum
DO $$ BEGIN
  CREATE TYPE "ShippingMethod" AS ENUM ('COURIER', 'PARCEL_LOCKER_INPOST', 'STORE_PICKUP');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- CreateEnum
DO $$ BEGIN
  CREATE TYPE "AddressBookEntryType" AS ENUM ('ADDRESS', 'PARCEL_LOCKER');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- AlterTable
ALTER TABLE "customer_orders"
ADD COLUMN IF NOT EXISTS "payment_method" "PaymentMethod" NOT NULL DEFAULT 'BLIK',
ADD COLUMN IF NOT EXISTS "shipping_method" "ShippingMethod" NOT NULL DEFAULT 'COURIER',
ADD COLUMN IF NOT EXISTS "shipping_snapshot" JSONB NOT NULL DEFAULT '{}'::jsonb,
ADD COLUMN IF NOT EXISTS "save_to_address_book" BOOLEAN NOT NULL DEFAULT true;

-- CreateTable
CREATE TABLE IF NOT EXISTS "address_book_entries" (
  "id" TEXT NOT NULL,
  "user_id" TEXT NOT NULL,
  "label" TEXT,
  "entry_type" "AddressBookEntryType" NOT NULL DEFAULT 'ADDRESS',
  "recipient_name" TEXT,
  "phone" TEXT,
  "email" TEXT,
  "country" TEXT NOT NULL DEFAULT 'PL',
  "postal_code" TEXT,
  "city" TEXT,
  "street" TEXT,
  "building_number" TEXT,
  "apartment_number" TEXT,
  "parcel_locker_id" TEXT,
  "parcel_locker_label" TEXT,
  "is_default" BOOLEAN NOT NULL DEFAULT false,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "address_book_entries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE IF NOT EXISTS "checkout_preferences" (
  "user_id" TEXT NOT NULL,
  "preferred_payment_method" "PaymentMethod",
  "preferred_shipping_method" "ShippingMethod",
  "preferred_address_id" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "checkout_preferences_pkey" PRIMARY KEY ("user_id")
);

-- CreateIndex
CREATE INDEX IF NOT EXISTS "address_book_entries_user_id_updated_at_idx"
ON "address_book_entries"("user_id", "updated_at");
