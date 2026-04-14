import { Injectable, NotFoundException } from '@nestjs/common';
import {
  AiProposalStatus,
  Prisma,
  ProductStatus,
  ReservationStatus,
} from '@prisma/client';
import { AuditService } from '../audit/audit.service';
import { HypeMakerService } from '../hype-maker/hype-maker.service';
import { PrismaService } from '../prisma/prisma.service';
import { MarketingAutomationService } from '../marketing-automation/marketing-automation.service';

type AnalyzeResult = {
  scannedProducts: number;
  generatedProposals: number;
  updatedExistingProposals: number;
  skippedProducts: number;
};

type AuditActor = {
  userId: string;
  userEmail?: string | null;
  ipAddress?: string | null;
};

@Injectable()
export class FinancialIntelligenceService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly marketingAutomation: MarketingAutomationService,
    private readonly hypeMaker: HypeMakerService,
    private readonly audit: AuditService,
  ) {}

  private toMoney(value: number): Prisma.Decimal {
    return new Prisma.Decimal(value.toFixed(2));
  }

  private scoreRisk(params: {
    paymentTermsDays: number;
    soldLast30: number;
    stockQty: number;
    stockValue: number;
    daysSinceLastSale: number;
  }): number {
    let score = 0;
    if (params.paymentTermsDays <= 7) score += 35;
    else if (params.paymentTermsDays <= 14) score += 25;
    else if (params.paymentTermsDays <= 21) score += 12;

    if (params.soldLast30 <= 0) score += 35;
    else {
      const stockToSalesRatio = params.stockQty / params.soldLast30;
      if (stockToSalesRatio >= 6) score += 28;
      else if (stockToSalesRatio >= 3) score += 16;
      else if (stockToSalesRatio >= 2) score += 8;
    }

    if (params.daysSinceLastSale >= 60) score += 20;
    else if (params.daysSinceLastSale >= 30) score += 10;

    if (params.stockValue >= 3000) score += 15;
    else if (params.stockValue >= 1000) score += 10;
    else if (params.stockValue >= 500) score += 5;

    return Math.min(100, Math.max(0, score));
  }

  private discountForRisk(riskScore: number): number {
    if (riskScore >= 90) return 24;
    if (riskScore >= 80) return 18;
    if (riskScore >= 70) return 12;
    return 0;
  }

  async analyzeCashflowRisk(): Promise<AnalyzeResult> {
    const now = new Date();
    const from30 = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

    const products = await this.prisma.product.findMany({
      where: {
        stockQty: { gt: 0 },
        purchasePriceNet: { not: null },
        supplier: { isNot: null },
      },
      select: {
        id: true,
        name: true,
        price: true,
        stockQty: true,
        purchasePriceNet: true,
        supplier: {
          select: {
            name: true,
            paymentTermsDays: true,
          },
        },
        reservations: {
          where: {
            status: {
              in: [ReservationStatus.ACCEPTED, ReservationStatus.FINALIZED],
            },
          },
          select: {
            quantity: true,
            updatedAt: true,
          },
        },
      },
    });

    let generatedProposals = 0;
    let updatedExistingProposals = 0;
    let skippedProducts = 0;

    for (const product of products) {
      const paymentTermsDays = product.supplier?.paymentTermsDays ?? null;
      const purchasePriceNet = product.purchasePriceNet
        ? Number(product.purchasePriceNet)
        : null;
      if (paymentTermsDays == null || purchasePriceNet == null) {
        skippedProducts += 1;
        continue;
      }

      const soldLast30 = product.reservations
        .filter((r) => r.updatedAt >= from30)
        .reduce((sum, r) => sum + r.quantity, 0);
      const lastSaleAt = product.reservations.reduce<Date | null>(
        (max, r) => (max == null || r.updatedAt > max ? r.updatedAt : max),
        null,
      );
      const daysSinceLastSale = lastSaleAt
        ? Math.floor(
            (now.getTime() - lastSaleAt.getTime()) / (24 * 60 * 60 * 1000),
          )
        : 999;
      const stockValue = Number(product.stockQty) * purchasePriceNet;

      const riskScore = this.scoreRisk({
        paymentTermsDays,
        soldLast30,
        stockQty: product.stockQty,
        stockValue,
        daysSinceLastSale,
      });
      const discountPercent = this.discountForRisk(riskScore);
      if (discountPercent <= 0) {
        continue;
      }

      const currentPrice = Number(product.price);
      const suggestedPriceNumber = currentPrice * (1 - discountPercent / 100);
      const suggestedPrice = this.toMoney(Math.max(0.01, suggestedPriceNumber));
      const rationale =
        `Ryzyko płynności: score=${riskScore}/100. ` +
        `Rotacja 30 dni: ${soldLast30} szt., stan: ${product.stockQty} szt., ` +
        `dni od ostatniej sprzedaży: ${daysSinceLastSale}, termin płatności dostawcy: ${paymentTermsDays} dni. ` +
        `Sugestia: obniżka o ${discountPercent}% dla szybszego uwolnienia gotówki.`;

      const existing = await this.prisma.aiProposal.findFirst({
        where: {
          productId: product.id,
          type: 'PRICE_DISCOUNT',
          status: AiProposalStatus.PENDING,
        },
        select: { id: true },
      });

      if (existing) {
        await this.prisma.aiProposal.update({
          where: { id: existing.id },
          data: {
            currentPrice: this.toMoney(currentPrice),
            suggestedPrice,
            discountPercent: this.toMoney(discountPercent),
            riskScore,
            rationale,
          },
        });
        updatedExistingProposals += 1;
      } else {
        await this.prisma.aiProposal.create({
          data: {
            type: 'PRICE_DISCOUNT',
            status: AiProposalStatus.PENDING,
            productId: product.id,
            currentPrice: this.toMoney(currentPrice),
            suggestedPrice,
            discountPercent: this.toMoney(discountPercent),
            riskScore,
            rationale,
          },
        });
        generatedProposals += 1;
      }
    }

    return {
      scannedProducts: products.length,
      generatedProposals,
      updatedExistingProposals,
      skippedProducts,
    };
  }

  async listProposals(status?: AiProposalStatus) {
    return this.prisma.aiProposal.findMany({
      where: status ? { status } : undefined,
      include: {
        product: {
          select: {
            id: true,
            name: true,
            price: true,
            stockQty: true,
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

  async acceptAndLaunchMarketing(proposalId: string, actor: AuditActor) {
    const proposal = await this.prisma.aiProposal.findUnique({
      where: { id: proposalId },
      include: { product: true },
    });
    if (!proposal) {
      throw new NotFoundException('Propozycja AI nie istnieje');
    }
    if (proposal.status !== AiProposalStatus.PENDING) {
      throw new NotFoundException('Propozycja nie jest już aktywna');
    }
    if (!proposal.productId || !proposal.product) {
      throw new NotFoundException('Brak powiązanego produktu');
    }

    const launchedAt = new Date();
    const result = await this.prisma.$transaction(async (tx) => {
      await tx.product.update({
        where: { id: proposal.productId! },
        data: {
          price: proposal.suggestedPrice,
          status: ProductStatus.PROMO,
          isFeatured: true,
          subtitle:
            'Oferta promocyjna uruchomiona automatycznie na podstawie analizy płynności.',
        },
      });
      const updatedProposal = await tx.aiProposal.update({
        where: { id: proposal.id },
        data: {
          status: AiProposalStatus.ACCEPTED,
          acceptedAt: launchedAt,
          acceptedByUserId: actor.userId,
          marketingLaunchedAt: launchedAt,
        },
      });
      return updatedProposal;
    });
    await this.marketingAutomation.createDraftForAcceptedProposal(
      {
        id: result.id,
        suggestedPrice: result.suggestedPrice,
        discountPercent: result.discountPercent,
        riskScore: result.riskScore,
        rationale: result.rationale,
      },
      {
        id: proposal.product.id,
        name: proposal.product.name,
        price: proposal.product.price,
      },
    );

    await this.hypeMaker
      .runForApprovedProposal({
        proposalId: result.id,
        productId: proposal.product.id,
        productName: proposal.product.name,
        discountPercent: result.discountPercent,
        suggestedPrice: result.suggestedPrice,
        riskScore: result.riskScore,
      })
      .catch((error: unknown) => {
        const message = error instanceof Error ? error.message : String(error);
        // Kampanie AI nie mogą blokować core flow akceptacji OWNER.
        void this.audit.logAction({
          userId: 'HYPE_MAKER_AI',
          userEmail: 'HYPE_MAKER_AI',
          action: 'HYPE_MAKER_ORCHESTRATION_FAILED',
          resourceType: 'AI_PROPOSAL',
          resourceId: proposalId,
          newValue: { message },
          ipAddress: actor.ipAddress ?? null,
        });
      });

    await this.audit.logAction({
      userId: actor.userId,
      userEmail:
        actor.userEmail?.trim() || `user-${actor.userId}@unknown.local`,
      action: 'ACCEPT_AI_PRICE_RECOMMENDATION',
      resourceType: 'AI_PROPOSAL',
      resourceId: proposalId,
      oldValue: {
        status: proposal.status,
        currentPrice: proposal.currentPrice.toString(),
        suggestedPrice: proposal.suggestedPrice.toString(),
      },
      newValue: {
        status: result.status,
        acceptedByUserId: result.acceptedByUserId,
        productStatus: ProductStatus.PROMO,
        suggestedPrice: result.suggestedPrice.toString(),
      },
      ipAddress: actor.ipAddress ?? null,
    });

    return {
      ok: true,
      marketingLaunched: true,
      proposal: result,
    };
  }

  async rejectProposal(proposalId: string, actor: AuditActor) {
    const proposal = await this.prisma.aiProposal.findUnique({
      where: { id: proposalId },
      select: {
        id: true,
        status: true,
        productId: true,
        currentPrice: true,
        suggestedPrice: true,
      },
    });
    if (!proposal) {
      throw new NotFoundException('Propozycja AI nie istnieje');
    }
    if (proposal.status !== AiProposalStatus.PENDING) {
      throw new NotFoundException('Propozycja nie jest już aktywna');
    }

    const rejected = await this.prisma.aiProposal.update({
      where: { id: proposalId },
      data: {
        status: AiProposalStatus.REJECTED,
      },
    });

    await this.audit.logAction({
      userId: actor.userId,
      userEmail:
        actor.userEmail?.trim() || `user-${actor.userId}@unknown.local`,
      action: 'REJECT_AI_PRICE_RECOMMENDATION',
      resourceType: 'AI_PROPOSAL',
      resourceId: proposalId,
      oldValue: {
        status: proposal.status,
        currentPrice: proposal.currentPrice.toString(),
        suggestedPrice: proposal.suggestedPrice.toString(),
      },
      newValue: {
        status: rejected.status,
        productId: proposal.productId,
      },
      ipAddress: actor.ipAddress ?? null,
    });

    return { ok: true, proposal: rejected };
  }
}
