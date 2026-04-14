-- Uwagi klienta, notatki staff, merchandising produktów
ALTER TABLE "customer_orders" ADD COLUMN IF NOT EXISTS "customer_note" TEXT;

ALTER TABLE "products" ADD COLUMN IF NOT EXISTS "subtitle" VARCHAR(512);
ALTER TABLE "products" ADD COLUMN IF NOT EXISTS "is_featured" BOOLEAN NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS "order_staff_notes" (
    "id" TEXT NOT NULL,
    "order_id" TEXT NOT NULL,
    "author_user_id" UUID NOT NULL,
    "body" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "order_staff_notes_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "order_staff_notes_order_id_created_at_idx" ON "order_staff_notes"("order_id", "created_at");

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'order_staff_notes_order_id_fkey'
  ) THEN
    ALTER TABLE "order_staff_notes"
      ADD CONSTRAINT "order_staff_notes_order_id_fkey"
      FOREIGN KEY ("order_id") REFERENCES "customer_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;
  END IF;
END $$;
