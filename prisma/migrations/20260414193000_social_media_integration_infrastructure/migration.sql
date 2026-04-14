-- CreateEnum
CREATE TYPE "SocialPlatform" AS ENUM ('INSTAGRAM', 'FACEBOOK', 'GOOGLE_ADS');

-- CreateEnum
CREATE TYPE "SocialConfigStatus" AS ENUM ('ACTIVE', 'INACTIVE', 'ERROR');

-- CreateEnum
CREATE TYPE "MarketingCampaignStatus" AS ENUM ('DRAFT', 'MOCK_SENT', 'FAILED');

-- CreateTable
CREATE TABLE "social_configs" (
    "id" TEXT NOT NULL,
    "platform" "SocialPlatform" NOT NULL,
    "access_token" TEXT NOT NULL,
    "refresh_token" TEXT,
    "status" "SocialConfigStatus" NOT NULL DEFAULT 'INACTIVE',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "social_configs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "marketing_campaigns" (
    "id" TEXT NOT NULL,
    "target" TEXT NOT NULL,
    "content" TEXT NOT NULL,
    "platform" "SocialPlatform" NOT NULL,
    "status" "MarketingCampaignStatus" NOT NULL DEFAULT 'DRAFT',
    "external_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "marketing_campaigns_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "social_configs_platform_key" ON "social_configs"("platform");

-- CreateIndex
CREATE INDEX "social_configs_status_updated_at_idx" ON "social_configs"("status", "updated_at");

-- CreateIndex
CREATE INDEX "marketing_campaigns_platform_status_created_at_idx" ON "marketing_campaigns"("platform", "status", "created_at");

-- CreateIndex
CREATE INDEX "marketing_campaigns_status_created_at_idx" ON "marketing_campaigns"("status", "created_at");
