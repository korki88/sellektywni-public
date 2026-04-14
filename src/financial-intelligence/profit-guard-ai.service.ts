import { Injectable, Logger } from '@nestjs/common';
import { AiProposalStatus, Prisma } from '@prisma/client';
import OpenAI from 'openai';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';

type ProfitGuardDecision = {
  shouldCreate: boolean;
  suggestedDiscountPercent: number;
  rationale: string;
};

type GenerateSummary = {
  scanned: number;
  candidates: number;
  generated: number;
  updated: number;
  skipped: number;
};

@Injectable()
export class ProfitGuardAiService {
  private readonly logger = new Logger(ProfitGuardAiService.name);
  private readonly systemUserId = 'SYSTEM_AI';
  private readonly systemEmail = 'SYSTEM_AI';

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  private toMoney(value: number): Prisma.Decimal {
    return new Prisma.Decimal(value.toFixed(2));
  }

  private decimalToNumber(value: Prisma.Decimal | null | undefined): number {
    if (!value) return 0;
    return Number(value);
  }

  private toNetFromGross(gross: number, vatRate: number): number {
    return gross / (1 + Math.max(0, vatRate) / 100);
  }

  private parseDecision(raw: string): ProfitGuardDecision | null {
    const normalized = raw
      .replace(/```json/gi, '')
      .replace(/```/g, '')
      .trim();
    try {
      const parsed = JSON.parse(normalized) as Partial<ProfitGuardDecision>;
      const shouldCreate = parsed.shouldCreate === true;
      const discount = Number(parsed.suggestedDiscountPercent);
      const suggestion = Number.isFinite(discount) ? discount : 0;
      const rationale = parsed.rationale?.toString().trim() ?? '';
      return {
        shouldCreate,
        suggestedDiscountPercent: Math.max(0, Math.min(40, suggestion)),
        rationale:
          rationale.length > 0
            ? rationale
            : 'Brak uzasadnienia z modelu AI; użyto fallbacku.',
      };
    } catch {
      return null;
    }
  }

  private fallbackDecision(params: {
    stockAgeDays: number;
    dueInDays: number;
    marginPercent: number;
    marginTarget: number;
  }): ProfitGuardDecision {
    const marginGap = Math.max(0, params.marginTarget - params.marginPercent);
    const urgency = params.dueInDays <= 0 ? 1.25 : 1;
    const stockPressure = params.stockAgeDays >= 90 ? 1.3 : 1;
    const proposed = Math.max(
      5,
      Math.min(25, (8 + marginGap * 0.45) * urgency * stockPressure),
    );
    return {
      shouldCreate: true,
      suggestedDiscountPercent: Number(proposed.toFixed(2)),
      rationale:
        'Fallback heurystyczny: wysoki wiek zapasu i bliski termin płatności zwiększają ryzyko zamrożenia gotówki.',
    };
  }

  private openAiClient(): OpenAI | null {
    const apiKey = process.env.OPENAI_API_KEY?.trim();
    if (!apiKey) return null;
    return new OpenAI({ apiKey });
  }

  private async decideWithAi(input: {
    productName: string;
    stockAgeDays: number;
    dueInDays: number;
    salePriceGross: number;
    purchasePriceNet: number;
    marginPercent: number;
    marginTarget: number;
  }): Promise<ProfitGuardDecision | null> {
    const client = this.openAiClient();
    if (!client) return null;

    const response = await client.chat.completions.create({
      model: 'gpt-4o',
      temperature: 0.2,
      messages: [
        {
          role: 'system',
          content:
            'Jesteś agentem Profit Guard dla e-commerce. Odpowiadasz WYŁĄCZNIE JSON-em.',
        },
        {
          role: 'user',
          content:
            'Przeanalizuj produkt i zdecyduj, czy tworzyć propozycję obniżki. ' +
            'Warunki wejściowe: stockAgeDays > 30, invoiceDueDate < 7 dni, analiza marży. ' +
            'Zwróć JSON: {"shouldCreate":boolean,"suggestedDiscountPercent":number,"rationale":string}. ' +
            'Rationale po polsku, zwięzłe (max 300 znaków). ' +
            `Dane: ${JSON.stringify(input)}.`,
        },
      ],
    });

    const raw = response.choices[0]?.message?.content?.trim();
    if (!raw) return null;
    return this.parseDecision(raw);
  }

  async generateProfitGuardProposals(): Promise<GenerateSummary> {
    const now = new Date();
    const products = await this.prisma.product.findMany({
      where: {
        stockQty: { gt: 0 },
        purchasePriceNet: { not: null },
        supplier: {
          is: {
            paymentTermsDays: { not: null },
          },
        },
      },
      select: {
        id: true,
        name: true,
        price: true,
        purchasePriceNet: true,
        vatRate: true,
        marginTarget: true,
        stockQty: true,
        createdAt: true,
        updatedAt: true,
        supplier: {
          select: {
            paymentTermsDays: true,
          },
        },
      },
      take: 1200,
      orderBy: { updatedAt: 'asc' },
    });

    let candidates = 0;
    let generated = 0;
    let updated = 0;
    let skipped = 0;

    for (const product of products) {
      const paymentTermsDays = product.supplier?.paymentTermsDays ?? null;
      if (paymentTermsDays == null) {
        skipped += 1;
        continue;
      }
      const stockAgeDays = Math.floor(
        (now.getTime() - product.updatedAt.getTime()) / (24 * 60 * 60 * 1000),
      );
      const invoiceDueDate = new Date(
        product.createdAt.getTime() + paymentTermsDays * 24 * 60 * 60 * 1000,
      );
      const dueInDays = Math.ceil(
        (invoiceDueDate.getTime() - now.getTime()) / (24 * 60 * 60 * 1000),
      );
      const salePriceGross = this.decimalToNumber(product.price);
      const purchasePriceNet = this.decimalToNumber(product.purchasePriceNet);
      const vatRate = this.decimalToNumber(product.vatRate);
      const marginTarget = this.decimalToNumber(product.marginTarget);
      const salePriceNet = this.toNetFromGross(salePriceGross, vatRate);
      const marginAmount = salePriceNet - purchasePriceNet;
      const marginPercent =
        salePriceNet > 0 ? (marginAmount / salePriceNet) * 100 : 0;

      if (stockAgeDays <= 30 || dueInDays >= 7) {
        skipped += 1;
        continue;
      }
      candidates += 1;

      const aiDecision =
        (await this.decideWithAi({
          productName: product.name,
          stockAgeDays,
          dueInDays,
          salePriceGross,
          purchasePriceNet,
          marginPercent: Number(marginPercent.toFixed(2)),
          marginTarget,
        }).catch((error: unknown) => {
          const message =
            error instanceof Error ? error.message : String(error);
          this.logger.warn(
            `OpenAI decision failed for ${product.id}: ${message}`,
          );
          return null;
        })) ?? null;

      const decision =
        aiDecision ??
        this.fallbackDecision({
          stockAgeDays,
          dueInDays,
          marginPercent,
          marginTarget,
        });

      if (!decision.shouldCreate || decision.suggestedDiscountPercent <= 0) {
        skipped += 1;
        continue;
      }

      const suggestedPrice = Math.max(
        0.01,
        salePriceGross * (1 - decision.suggestedDiscountPercent / 100),
      );
      const riskScore = Math.max(
        0,
        Math.min(
          100,
          Math.round(
            (stockAgeDays > 60 ? 55 : 35) +
              (dueInDays <= 0 ? 30 : 20) +
              (marginPercent < marginTarget ? 15 : 5),
          ),
        ),
      );
      const rationale =
        `${decision.rationale} ` +
        `(stockAge=${stockAgeDays}d, dueIn=${dueInDays}d, margin=${marginPercent.toFixed(2)}%).`;

      const existing = await this.prisma.aiProposal.findFirst({
        where: {
          productId: product.id,
          type: 'PROFIT_GUARD_DISCOUNT',
          status: AiProposalStatus.PENDING,
        },
        select: { id: true },
      });

      let proposalId: string;
      if (existing) {
        const updatedRow = await this.prisma.aiProposal.update({
          where: { id: existing.id },
          data: {
            currentPrice: this.toMoney(salePriceGross),
            suggestedPrice: this.toMoney(suggestedPrice),
            discountPercent: this.toMoney(decision.suggestedDiscountPercent),
            riskScore,
            rationale,
          },
        });
        proposalId = updatedRow.id;
        updated += 1;
      } else {
        const createdRow = await this.prisma.aiProposal.create({
          data: {
            type: 'PROFIT_GUARD_DISCOUNT',
            status: AiProposalStatus.PENDING,
            productId: product.id,
            currentPrice: this.toMoney(salePriceGross),
            suggestedPrice: this.toMoney(suggestedPrice),
            discountPercent: this.toMoney(decision.suggestedDiscountPercent),
            riskScore,
            rationale,
          },
        });
        proposalId = createdRow.id;
        generated += 1;
      }

      await this.audit.logAction({
        userId: this.systemUserId,
        userEmail: this.systemEmail,
        action: 'FINANCIAL_CALCULATION',
        resourceType: 'AI_PROPOSAL',
        resourceId: proposalId,
        newValue: {
          type: 'PROFIT_GUARD_DISCOUNT',
          productId: product.id,
          stockAgeDays,
          dueInDays,
          marginPercent: Number(marginPercent.toFixed(2)),
          suggestedDiscountPercent: decision.suggestedDiscountPercent,
          rationale,
        },
      });
    }

    return {
      scanned: products.length,
      candidates,
      generated,
      updated,
      skipped,
    };
  }

  async listProfitGuardProposals() {
    return this.prisma.aiProposal.findMany({
      where: { type: 'PROFIT_GUARD_DISCOUNT' },
      include: {
        product: {
          select: {
            id: true,
            name: true,
            price: true,
            stockQty: true,
            purchasePriceNet: true,
            vatRate: true,
            marginTarget: true,
            supplier: {
              select: { name: true, paymentTermsDays: true },
            },
          },
        },
      },
      orderBy: [{ status: 'asc' }, { createdAt: 'desc' }],
      take: 300,
    });
  }
}
