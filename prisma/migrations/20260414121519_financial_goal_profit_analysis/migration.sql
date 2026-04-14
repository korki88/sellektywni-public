-- CreateTable
CREATE TABLE "financial_goals" (
    "id" TEXT NOT NULL,
    "month" VARCHAR(7) NOT NULL,
    "revenue_target" DECIMAL(12,2) NOT NULL,
    "profit_target" DECIMAL(12,2) NOT NULL,
    "fixed_costs" DECIMAL(12,2) NOT NULL,
    "burn_rate" DECIMAL(12,2) NOT NULL,
    "notes" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "financial_goals_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "financial_goals_month_key" ON "financial_goals"("month");

-- CreateIndex
CREATE INDEX "financial_goals_month_idx" ON "financial_goals"("month");
