import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
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

  async listOffer(opts?: { search?: string }) {
    const q = opts?.search?.trim();
    const where: Prisma.ProductWhereInput = {
      stockQty: { gt: 0 },
    };
    if (q) {
      where.name = { contains: q, mode: 'insensitive' };
    }
    const products = await this.prisma.product.findMany({
      where,
      orderBy: { createdAt: 'asc' },
      include: {
        reservations: {
          where: {
            status: { in: [ReservationStatus.IN_CART, ReservationStatus.PENDING] },
          },
          select: { quantity: true },
        },
      },
    });
    return products.map(({ reservations, ...p }) => {
      const reservedQty = reservations.reduce((sum, r) => sum + r.quantity, 0);
      const availableQty = Math.max(0, p.stockQty - reservedQty);
      const forcedReserved = p.status === ProductStatus.RESERVED && availableQty > 0;
      const canAddToCart = availableQty > 0 && !forcedReserved;
      const visualStatus = canAddToCart ? ProductStatus.AVAILABLE : ProductStatus.RESERVED;
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
    const rows = await this.prisma.productReview.findMany({
      where: { productId, isVisible: true },
      orderBy: { createdAt: 'desc' },
      take: 80,
      select: {
        id: true,
        userId: true,
        rating: true,
        comment: true,
        createdAt: true,
      },
    });
    const summary = await this.prisma.productReview.aggregate({
      where: { productId, isVisible: true },
      _avg: { rating: true },
      _count: { _all: true },
    });
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
    if (!Number.isFinite(rating) || rating < 1 || rating > 5) {
      throw new BadRequestException('Ocena musi być w skali 1–5.');
    }
    const product = await this.prisma.product.findUnique({ where: { id: productId } });
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
