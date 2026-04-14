import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AuditService } from '../audit/audit.service';
import { DotykackaService } from '../dotykacka/dotykacka.service';
import { PrismaService } from '../prisma/prisma.service';

type AuditActor = {
  userId: string;
  userEmail?: string | null;
  ipAddress?: string | null;
};

type UpsertFinancialGoalInput = {
  month: string;
  revenueTarget: number;
  profitTarget: number;
  fixedCosts: number;
  burnRate: number;
  notes?: string | null;
};

@Injectable()
export class ProfitAnalysisService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly dotykacka: DotykackaService,
    private readonly audit: AuditService,
  ) {}

  private toMoney(value: number): Prisma.Decimal {
    return new Prisma.Decimal(value.toFixed(2));
  }

  private decimalToNumber(value: Prisma.Decimal | null | undefined): number {
    if (!value) return 0;
    return Number(value);
  }

  private asMonth(raw: string): string {
    return raw.trim();
  }

  private vatMultiplier(vatRate: number): number {
    return 1 + Math.max(0, vatRate) / 100;
  }

  private toNetFromGross(gross: number, vatRate: number): number {
    return gross / this.vatMultiplier(vatRate);
  }

  private toGrossFromNet(net: number, vatRate: number): number {
    return net * this.vatMultiplier(vatRate);
  }

  private extractRemoteSalePrice(payload: unknown): number | null {
    if (!payload || typeof payload !== 'object') return null;
    const row = payload as Record<string, unknown>;
    const candidates = [
      row['price'],
      row['salePrice'],
      row['priceWithVat'],
      row['finalPrice'],
      row['amount'],
    ];
    for (const candidate of candidates) {
      if (typeof candidate === 'number' && Number.isFinite(candidate)) {
        return candidate > 0 ? candidate : null;
      }
      if (typeof candidate === 'string') {
        const parsed = Number(candidate.replace(',', '.').trim());
        if (Number.isFinite(parsed) && parsed > 0) return parsed;
      }
    }
    return null;
  }

  private async resolveGrossSalePrice(
    idDotykacka: string,
    localFallback: number,
  ): Promise<{ price: number; source: 'dotykacka' | 'local' }> {
    try {
      const payload = await this.dotykacka.getProduct(idDotykacka);
      const remote = this.extractRemoteSalePrice(payload);
      if (remote && remote > 0) {
        return { price: remote, source: 'dotykacka' };
      }
      return { price: localFallback, source: 'local' };
    } catch {
      return { price: localFallback, source: 'local' };
    }
  }

  async listGoals() {
    return this.prisma.financialGoal.findMany({
      orderBy: { month: 'desc' },
      take: 60,
    });
  }

  async createGoal(data: UpsertFinancialGoalInput) {
    return this.prisma.financialGoal.create({
      data: {
        month: this.asMonth(data.month),
        revenueTarget: this.toMoney(data.revenueTarget),
        profitTarget: this.toMoney(data.profitTarget),
        fixedCosts: this.toMoney(data.fixedCosts),
        burnRate: this.toMoney(data.burnRate),
        notes: data.notes?.trim() || null,
      },
    });
  }

  async updateGoal(goalId: string, data: Partial<UpsertFinancialGoalInput>) {
    return this.prisma.financialGoal.update({
      where: { id: goalId },
      data: {
        ...(data.month !== undefined
          ? { month: this.asMonth(data.month) }
          : {}),
        ...(data.revenueTarget !== undefined
          ? { revenueTarget: this.toMoney(data.revenueTarget) }
          : {}),
        ...(data.profitTarget !== undefined
          ? { profitTarget: this.toMoney(data.profitTarget) }
          : {}),
        ...(data.fixedCosts !== undefined
          ? { fixedCosts: this.toMoney(data.fixedCosts) }
          : {}),
        ...(data.burnRate !== undefined
          ? { burnRate: this.toMoney(data.burnRate) }
          : {}),
        ...(data.notes !== undefined
          ? { notes: data.notes?.trim() || null }
          : {}),
      },
    });
  }

  async summary(actor: AuditActor) {
    const products = await this.prisma.product.findMany({
      where: {
        purchasePriceNet: { not: null },
      },
      select: {
        id: true,
        idDotykacka: true,
        name: true,
        stockQty: true,
        price: true,
        purchasePriceNet: true,
        vatRate: true,
        marginTarget: true,
      },
      orderBy: { createdAt: 'asc' },
      take: 2000,
    });

    const productRows = await Promise.all(
      products.map(async (product) => {
        const vatRate = this.decimalToNumber(product.vatRate);
        const purchaseNet = this.decimalToNumber(product.purchasePriceNet);
        const localGross = this.decimalToNumber(product.price);
        const sale = await this.resolveGrossSalePrice(
          product.idDotykacka,
          localGross,
        );
        const saleNet = this.toNetFromGross(sale.price, vatRate);
        const marginAmount = saleNet - purchaseNet;
        const marginPercent = saleNet > 0 ? (marginAmount / saleNet) * 100 : 0;
        const breakEvenPriceGross = this.toGrossFromNet(purchaseNet, vatRate);
        const stockQty = Math.max(0, product.stockQty);
        const inventoryPurchaseValueNet = purchaseNet * stockQty;
        const potentialProfitNet = marginAmount * stockQty;
        return {
          productId: product.id,
          idDotykacka: product.idDotykacka,
          name: product.name,
          stockQty,
          vatRate,
          marginTarget: this.decimalToNumber(product.marginTarget),
          salePriceGross: Number(sale.price.toFixed(2)),
          salePriceSource: sale.source,
          salePriceNet: Number(saleNet.toFixed(2)),
          purchasePriceNet: Number(purchaseNet.toFixed(2)),
          marginAmountNet: Number(marginAmount.toFixed(2)),
          marginPercent: Number(marginPercent.toFixed(2)),
          breakEvenPriceGross: Number(breakEvenPriceGross.toFixed(2)),
          inventoryPurchaseValueNet: Number(
            inventoryPurchaseValueNet.toFixed(2),
          ),
          potentialProfitNet: Number(potentialProfitNet.toFixed(2)),
        };
      }),
    );

    const totals = productRows.reduce(
      (acc, row) => {
        acc.inventoryPurchaseValueNet += row.inventoryPurchaseValueNet;
        acc.potentialProfitNet += row.potentialProfitNet;
        return acc;
      },
      {
        inventoryPurchaseValueNet: 0,
        potentialProfitNet: 0,
      },
    );

    const month = new Date().toISOString().slice(0, 7);
    const goal = await this.prisma.financialGoal.findUnique({
      where: { month },
    });

    const payload = {
      month,
      totalProducts: productRows.length,
      inventoryPurchaseValueNet: Number(
        totals.inventoryPurchaseValueNet.toFixed(2),
      ),
      potentialProfitNet: Number(totals.potentialProfitNet.toFixed(2)),
      goal:
        goal == null
          ? null
          : {
              id: goal.id,
              month: goal.month,
              revenueTarget: goal.revenueTarget.toString(),
              profitTarget: goal.profitTarget.toString(),
              fixedCosts: goal.fixedCosts.toString(),
              burnRate: goal.burnRate.toString(),
              notes: goal.notes,
            },
      products: productRows,
    };

    await this.audit.logAction({
      userId: actor.userId,
      userEmail:
        actor.userEmail?.trim() || `user-${actor.userId}@unknown.local`,
      action: 'FINANCIAL_CALCULATION',
      resourceType: 'FINANCE',
      resourceId: 'SUMMARY',
      newValue: payload,
      ipAddress: actor.ipAddress ?? null,
    });

    return payload;
  }
}
