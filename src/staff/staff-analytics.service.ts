import { Injectable } from '@nestjs/common';
import {
  PaymentStatus,
  Prisma,
  ProductStatus,
  ProfileRole,
} from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

export type ShopAnalyticsSummary = {
  generatedAt: string;
  ordersByStatus: Record<string, number>;
  reservationsByStatus: Record<string, number>;
  paidOrdersCount: number;
  paidRevenueTotal: string;
  pendingPaymentCount: number;
  revenueByPaymentMethod: { paymentMethod: string; total: string }[];
  products: {
    total: number;
    available: number;
    lowStockThreshold: number;
    lowStockCount: number;
  };
  customersCount: number;
};

@Injectable()
export class StaffAnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  async getSummary(): Promise<ShopAnalyticsSummary> {
    const lowThreshold = 3;
    const [
      orderGroups,
      reservationGroups,
      paidAgg,
      pendingPayCount,
      revByPm,
      productTotal,
      productAvailable,
      lowStockCount,
      customersCount,
      paidOrdersCount,
    ] = await Promise.all([
      this.prisma.customerOrder.groupBy({
        by: ['status'],
        _count: { _all: true },
      }),
      this.prisma.productReservation.groupBy({
        by: ['status'],
        _count: { _all: true },
      }),
      this.prisma.customerOrder.aggregate({
        where: { paymentStatus: PaymentStatus.PAID },
        _sum: { totalAmount: true },
      }),
      this.prisma.customerOrder.count({
        where: { paymentStatus: PaymentStatus.PENDING },
      }),
      this.prisma.customerOrder.groupBy({
        by: ['paymentMethod'],
        where: { paymentStatus: PaymentStatus.PAID },
        _sum: { totalAmount: true },
      }),
      this.prisma.product.count(),
      this.prisma.product.count({
        where: { status: ProductStatus.AVAILABLE },
      }),
      this.prisma.product.count({
        where: {
          status: ProductStatus.AVAILABLE,
          stockQty: { lte: lowThreshold },
        },
      }),
      this.prisma.profile.count({ where: { role: ProfileRole.CUSTOMER } }),
      this.prisma.customerOrder.count({
        where: { paymentStatus: PaymentStatus.PAID },
      }),
    ]);

    const ordersByStatus: Record<string, number> = {};
    for (const g of orderGroups) {
      ordersByStatus[g.status] = g._count._all;
    }
    const reservationsByStatus: Record<string, number> = {};
    for (const g of reservationGroups) {
      reservationsByStatus[g.status] = g._count._all;
    }

    const revenueByPaymentMethod = revByPm.map((r) => ({
      paymentMethod: r.paymentMethod,
      total: (r._sum.totalAmount ?? new Prisma.Decimal(0)).toString(),
    }));

    return {
      generatedAt: new Date().toISOString(),
      ordersByStatus,
      reservationsByStatus,
      paidOrdersCount,
      paidRevenueTotal: (
        paidAgg._sum.totalAmount ?? new Prisma.Decimal(0)
      ).toString(),
      pendingPaymentCount: pendingPayCount,
      revenueByPaymentMethod,
      products: {
        total: productTotal,
        available: productAvailable,
        lowStockThreshold: lowThreshold,
        lowStockCount,
      },
      customersCount: customersCount,
    };
  }

  async listLowStock(threshold: number) {
    const t =
      Number.isFinite(threshold) && threshold > 0 ? Math.floor(threshold) : 3;
    const rows = await this.prisma.product.findMany({
      where: {
        status: ProductStatus.AVAILABLE,
        stockQty: { lte: t },
      },
      select: {
        id: true,
        name: true,
        stockQty: true,
        idDotykacka: true,
        status: true,
      },
      orderBy: [{ stockQty: 'asc' }, { name: 'asc' }],
      take: 200,
    });
    return rows.map((r) => ({
      id: r.id,
      name: r.name,
      stockQty: r.stockQty,
      idDotykacka: r.idDotykacka,
      status: r.status,
    }));
  }
}
