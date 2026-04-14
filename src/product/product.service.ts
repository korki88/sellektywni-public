import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, ProductStatus, ReservationStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ProductService {
  constructor(private readonly prisma: PrismaService) {}

  private normalizeSearchText(input: string): string {
    return input
      .toLowerCase()
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/[^\p{L}\p{N}\s-]/gu, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private levenshtein(a: string, b: string): number {
    if (a === b) return 0;
    if (!a.length) return b.length;
    if (!b.length) return a.length;
    const prev = Array.from({ length: b.length + 1 }, (_, i) => i);
    const curr = new Array<number>(b.length + 1).fill(0);
    for (let i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (let j = 1; j <= b.length; j++) {
        const cost = a[i - 1] === b[j - 1] ? 0 : 1;
        curr[j] = Math.min(
          curr[j - 1] + 1,
          prev[j] + 1,
          prev[j - 1] + cost,
        );
      }
      for (let j = 0; j <= b.length; j++) prev[j] = curr[j];
    }
    return prev[b.length];
  }

  private searchScore(queryRaw: string, nameRaw: string): number {
    const query = this.normalizeSearchText(queryRaw);
    const name = this.normalizeSearchText(nameRaw);
    if (!query || !name) return 0;
    if (name === query) return 1000;
    if (name.startsWith(query)) return 900;
    if (name.includes(query)) return 760;
    const nameWords = name.split(' ').filter(Boolean);
    const queryWords = query.split(' ').filter(Boolean);
    if (queryWords.every((w) => nameWords.some((n) => n.startsWith(w)))) return 700;
    let best = 0;
    for (const nw of nameWords) {
      const dist = this.levenshtein(query, nw);
      const ratio = 1 - dist / Math.max(query.length, nw.length);
      best = Math.max(best, ratio);
    }
    const wholeDist = this.levenshtein(query, name);
    const wholeRatio = 1 - wholeDist / Math.max(query.length, name.length);
    best = Math.max(best, wholeRatio);
    if (best < 0.45) return 0;
    return Math.round(best * 650);
  }

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
    const offset = opts?.offset ?? 0;
    const limit = opts?.limit;
    const where: Prisma.ProductWhereInput = {
      stockQty: { gt: 0 },
    };
    if (opts?.featuredOnly) {
      where.isFeatured = true;
    }

    // Dla wyszukiwania „inteligentnego” pobieramy kandydatów i sortujemy po podobieństwie.
    if (q) {
      const candidates = await this.prisma.product.findMany({
        where,
        orderBy: { createdAt: 'asc' },
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
      const scored = candidates
        .map(({ reservations, ...p }) => {
          const reservedQty = reservations.reduce((sum, r) => sum + r.quantity, 0);
          const availableQty = Math.max(0, p.stockQty - reservedQty);
          const forcedReserved =
            p.status === ProductStatus.RESERVED && availableQty > 0;
          const canAddToCart = availableQty > 0 && !forcedReserved;
          const visualStatus = canAddToCart
            ? ProductStatus.AVAILABLE
            : ProductStatus.RESERVED;
          const score = this.searchScore(q, p.name);
          return {
            ...p,
            reservedQty,
            availableQty,
            canAddToCart,
            visualStatus,
            _score: score,
          };
        })
        .filter((row) => row._score > 0)
        .sort((a, b) => b._score - a._score || a.createdAt.getTime() - b.createdAt.getTime());

      const from = Math.max(0, offset);
      const to = limit ? from + Math.max(1, limit) : undefined;
      return scored.slice(from, to).map(({ _score, ...rest }) => rest);
    }

    const products = await this.prisma.product.findMany({
      where,
      orderBy: { createdAt: 'asc' },
      skip: offset,
      take: limit,
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
