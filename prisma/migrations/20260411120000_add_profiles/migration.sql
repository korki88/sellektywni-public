-- CreateEnum
CREATE TYPE "ProfileRole" AS ENUM ('CUSTOMER', 'STAFF', 'OWNER');

-- CreateEnum
CREATE TYPE "ProfileRank" AS ENUM ('BRONZE', 'SILVER', 'GOLD', 'VINTAGE');

-- CreateTable
CREATE TABLE "profiles" (
    "user_id" UUID NOT NULL,
    "email" TEXT,
    "role" "ProfileRole" NOT NULL DEFAULT 'CUSTOMER',
    "points" INTEGER NOT NULL DEFAULT 0,
    "rank" "ProfileRank" NOT NULL DEFAULT 'BRONZE',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "profiles_pkey" PRIMARY KEY ("user_id")
);
