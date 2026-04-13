-- CreateTable
CREATE TABLE "availability_watches" (
    "id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "product_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "availability_watches_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "availability_watches_user_id_product_id_key" ON "availability_watches"("user_id", "product_id");

-- CreateIndex
CREATE INDEX "availability_watches_product_id_idx" ON "availability_watches"("product_id");

-- AddForeignKey
ALTER TABLE "availability_watches" ADD CONSTRAINT "availability_watches_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;
