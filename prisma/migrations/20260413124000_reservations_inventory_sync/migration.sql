-- AlterEnum
ALTER TYPE "ProductStatus" ADD VALUE IF NOT EXISTS 'RESERVED';

-- AlterEnum
ALTER TYPE "ReservationStatus" ADD VALUE IF NOT EXISTS 'IN_CART';
ALTER TYPE "ReservationStatus" ADD VALUE IF NOT EXISTS 'AUTO_REJECTED';

-- AlterTable
ALTER TABLE "products"
ADD COLUMN "stock_qty" INTEGER NOT NULL DEFAULT 1;

-- AlterTable
ALTER TABLE "product_reservations"
ADD COLUMN "owner_key" TEXT NOT NULL DEFAULT 'unknown';

-- CreateIndex
CREATE UNIQUE INDEX "product_reservations_owner_key_product_id_status_key"
ON "product_reservations"("owner_key", "product_id", "status");
