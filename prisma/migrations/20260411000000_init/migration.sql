-- CreateEnum
CREATE TYPE "ProductStatus" AS ENUM ('AVAILABLE', 'PENDING_APPROVAL', 'SOLD', 'IN_FITTING_ROOM');

-- CreateTable
CREATE TABLE "products" (
    "id" TEXT NOT NULL,
    "id_dotykacka" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "price" DECIMAL(12,2) NOT NULL,
    "status" "ProductStatus" NOT NULL DEFAULT 'AVAILABLE',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "products_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "products_id_dotykacka_key" ON "products"("id_dotykacka");
