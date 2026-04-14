-- CreateEnum
CREATE TYPE "ReturnRequestStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'RECEIVED');

-- AlterTable
ALTER TABLE "customer_orders" ALTER COLUMN "shipping_snapshot" DROP DEFAULT;

-- AlterTable
ALTER TABLE "profiles" ADD COLUMN     "newsletter_opt_in" BOOLEAN NOT NULL DEFAULT false,
ALTER COLUMN "updated_at" DROP DEFAULT;

-- CreateTable
CREATE TABLE "return_requests" (
    "id" TEXT NOT NULL,
    "user_id" UUID NOT NULL,
    "order_id" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "status" "ReturnRequestStatus" NOT NULL DEFAULT 'PENDING',
    "staff_note" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "return_requests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "return_requests_order_id_key" ON "return_requests"("order_id");

-- CreateIndex
CREATE INDEX "return_requests_user_id_created_at_idx" ON "return_requests"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "return_requests_status_idx" ON "return_requests"("status");

-- AddForeignKey
ALTER TABLE "return_requests" ADD CONSTRAINT "return_requests_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "customer_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
