import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, ProductStatus, ReservationStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ProductService {
  constructor(private readonly prisma: PrismaService) {}

  findByIdOrDotykacka(productId?: string, idDotykacka?: string) {
    if (productId) {
      return this.prisma.product.findUnique({ where: { id: productId } });
    }
    if (idDotykacka) {
      return this.prisma.product.findUnique({ where: { idDotykacka } });
    }
    return Promise.resolve(null);
  }

  /**
   * Stan oferty dla jednego produktu (jak w listOffer) — używane m.in. przy „ponów zamówienie”.
   */
  async getOfferSnapshot(productId: string) {
    const row = await this.prisma.product.findUnique({
      where: { id: productId },
      include: {
        reservations: {
          where: {
            status: {
              in: [ReservationStatus.IN_CART, ReservationStatus.PENDING],
            },
          },
          select: { quantity: true },
        },
      },
    });
    if (!row) return null;
    const reservedQty = row.reservations.reduce((s, r) => s + r.quantity, 0);
    const availableQty = Math.max(0, row.stockQty - reservedQty);
    const forcedReserved =
      row.status === ProductStatus.RESERVED && availableQty > 0;
    const canAddToCart = availableQty > 0 && !forcedReserved;
    return {
      id: row.id,
      name: row.name,
      price: row.price,
      status: row.status,
      availableQty,
      canAddToCart,
    };
  }

  async listOffer(opts?: {
    search?: string;
    featuredOnly?: boolean;
    offset?: number;
    limit?: number;
  }) {
    const q = opts?.search?.trim();
    const where: Prisma.ProductWhereInput = {
      stockQty: { gt: 0 },
    };
    if (opts?.featuredOnly) {
      where.isFeatured = true;
    }
    if (q) {
      where.name = { contains: q, mode: 'insensitive' };
    }
    const products = await this.prisma.product.findMany({
      where,
      orderBy: { createdAt: 'asc' },
      skip: opts?.offset,
      take: opts?.limit,
      include: {
        reservations: {
          where: {
            status: {
              in: [ReservationStatus.IN_CART, ReservationStatus.PENDING],
            },
          },
          select: { quantity: true },
        },
      },
    });
    return products.map(({ reservations, ...p }) => {
      const reservedQty = reservations.reduce((sum, r) => sum + r.quantity, 0);
      const availableQty = Math.max(0, p.stockQty - reservedQty);
      const forcedReserved =
        p.status === ProductStatus.RESERVED && availableQty > 0;
      const canAddToCart = availableQty > 0 && !forcedReserved;
      const visualStatus = canAddToCart
        ? ProductStatus.AVAILABLE
        : ProductStatus.RESERVED;
      return {
        ...p,
        reservedQty,
        availableQty,
        canAddToCart,
        visualStatus,
      };
    });
  }

  async listPublicReviews(productId: string) {
    const where = { productId, isVisible: true };
    const [rows, summary] = await Promise.all([
      this.prisma.productReview.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take: 80,
        select: {
          id: true,
          userId: true,
          rating: true,
          comment: true,
          createdAt: true,
        },
      }),
      this.prisma.productReview.aggregate({
        where,
        _avg: { rating: true },
        _count: { _all: true },
      }),
    ]);
    return {
      averageRating: summary._avg.rating,
      reviewCount: summary._count._all,
      reviews: rows,
    };
  }

  async addProductReview(
    userId: string,
    productId: string,
    rating: number,
    comment?: string,
  ) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
    });
    if (!product) throw new NotFoundException('Produkt nie istnieje');
    const row = await this.prisma.productReview.upsert({
      where: {
        userId_productId: { userId, productId },
      },
      create: {
        userId,
        productId,
        rating: Math.round(rating),
        comment: comment?.trim() || null,
      },
      update: {
        rating: Math.round(rating),
        comment: comment?.trim() || null,
      },
    });
    return row;
  }
}
