-- CreateEnum
CREATE TYPE "SupportTicketStatus" AS ENUM ('OPEN', 'ANSWERED', 'CLOSED');

-- AlterTable profiles
ALTER TABLE "profiles" ADD COLUMN "preferred_locale" TEXT NOT NULL DEFAULT 'pl';
ALTER TABLE "profiles" ADD COLUMN "referral_code" TEXT;
ALTER TABLE "profiles" ADD COLUMN "referred_by_user_id" UUID;
ALTER TABLE "profiles" ADD COLUMN "customer_segment" TEXT NOT NULL DEFAULT 'DEFAULT';

CREATE UNIQUE INDEX "profiles_referral_code_key" ON "profiles"("referral_code");

ALTER TABLE "profiles" ADD CONSTRAINT "profiles_referred_by_user_id_fkey" FOREIGN KEY ("referred_by_user_id") REFERENCES "profiles"("user_id") ON DELETE SET NULL ON UPDATE CASCADE;

-- CreateTable gift_cards
CREATE TABLE "gift_cards" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "balance_amount" DECIMAL(12,2) NOT NULL,
    "initial_amount" DECIMAL(12,2) NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'PLN',
    "active" BOOLEAN NOT NULL DEFAULT true,
    "expires_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "gift_cards_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "gift_cards_code_key" ON "gift_cards"("code");

-- CreateTable cms_pages
CREATE TABLE "cms_pages" (
    "id" TEXT NOT NULL,
    "slug" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "body_markdown" TEXT NOT NULL,
    "published" BOOLEAN NOT NULL DEFAULT false,
    "seo_title" TEXT,
    "seo_description" TEXT,
    "seo_keywords" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "cms_pages_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "cms_pages_slug_key" ON "cms_pages"("slug");

-- CreateTable support_tickets
CREATE TABLE "support_tickets" (
    "id" TEXT NOT NULL,
    "user_id" UUID NOT NULL,
    "subject" TEXT NOT NULL,
    "status" "SupportTicketStatus" NOT NULL DEFAULT 'OPEN',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "support_tickets_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "support_tickets_user_id_created_at_idx" ON "support_tickets"("user_id", "created_at");

-- CreateTable support_messages
CREATE TABLE "support_messages" (
    "id" TEXT NOT NULL,
    "ticket_id" TEXT NOT NULL,
    "author_user_id" UUID,
    "body" TEXT NOT NULL,
    "is_staff" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "support_messages_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "support_messages_ticket_id_created_at_idx" ON "support_messages"("ticket_id", "created_at");

ALTER TABLE "support_messages" ADD CONSTRAINT "support_messages_ticket_id_fkey" FOREIGN KEY ("ticket_id") REFERENCES "support_tickets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- CreateTable abandoned_cart_reminders
CREATE TABLE "abandoned_cart_reminders" (
    "id" TEXT NOT NULL,
    "user_id" UUID NOT NULL,
    "sent_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "abandoned_cart_reminders_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "abandoned_cart_reminders_user_id_sent_at_idx" ON "abandoned_cart_reminders"("user_id", "sent_at");

-- CreateTable experiments
CREATE TABLE "experiments" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "variants" JSONB NOT NULL DEFAULT '["control", "variant_b"]'::jsonb,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "experiments_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "experiments_key_key" ON "experiments"("key");

-- CreateTable experiment_assignments
CREATE TABLE "experiment_assignments" (
    "id" TEXT NOT NULL,
    "user_id" UUID NOT NULL,
    "experiment_key" TEXT NOT NULL,
    "variant" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "experiment_assignments_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "experiment_assignments_user_id_experiment_key_key" ON "experiment_assignments"("user_id", "experiment_key");

-- AlterTable customer_orders
ALTER TABLE "customer_orders" ADD COLUMN "gift_card_discount_amount" DECIMAL(12,2) NOT NULL DEFAULT 0;
ALTER TABLE "customer_orders" ADD COLUMN "referral_discount_amount" DECIMAL(12,2) NOT NULL DEFAULT 0;
ALTER TABLE "customer_orders" ADD COLUMN "gift_card_id" TEXT;
ALTER TABLE "customer_orders" ADD COLUMN "referral_code_applied" TEXT;

ALTER TABLE "customer_orders" ADD CONSTRAINT "customer_orders_gift_card_id_fkey" FOREIGN KEY ("gift_card_id") REFERENCES "gift_cards"("id") ON DELETE SET NULL ON UPDATE CASCADE;
