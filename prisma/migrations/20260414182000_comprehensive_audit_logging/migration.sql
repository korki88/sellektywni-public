-- AlterTable
ALTER TABLE "audit_logs"
ADD COLUMN "user_email" TEXT,
ADD COLUMN "resource_type" TEXT,
ADD COLUMN "old_value" JSONB,
ADD COLUMN "new_value" JSONB,
ADD COLUMN "ip_address" TEXT;

-- Backfill existing rows for new required columns.
UPDATE "audit_logs" AS al
SET "user_email" = COALESCE(
  NULLIF(p."email", ''),
  ('user-' || al."user_id"::text || '@unknown.local')
)
FROM "profiles" AS p
WHERE p."user_id" = al."user_id"
  AND (al."user_email" IS NULL OR al."user_email" = '');

UPDATE "audit_logs"
SET "user_email" = ('user-' || "user_id"::text || '@unknown.local')
WHERE "user_email" IS NULL OR "user_email" = '';

UPDATE "audit_logs"
SET "resource_type" = 'UNKNOWN'
WHERE "resource_type" IS NULL OR "resource_type" = '';

UPDATE "audit_logs"
SET "resource_id" = 'UNKNOWN'
WHERE "resource_id" IS NULL OR "resource_id" = '';

-- Enforce mandatory fields.
ALTER TABLE "audit_logs"
ALTER COLUMN "user_email" SET NOT NULL,
ALTER COLUMN "resource_type" SET NOT NULL,
ALTER COLUMN "resource_id" SET NOT NULL;

-- CreateIndex
CREATE INDEX "audit_logs_action_created_at_idx" ON "audit_logs"("action", "created_at");

-- CreateIndex
CREATE INDEX "audit_logs_resource_type_resource_id_created_at_idx"
ON "audit_logs"("resource_type", "resource_id", "created_at");
