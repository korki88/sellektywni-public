import { Injectable } from '@nestjs/common';
import { ProductStatus, ReservationStatus } from '@prisma/client';
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

  async listOffer() {
    const products = await this.prisma.product.findMany({
      where: {
        stockQty: { gt: 0 },
      },
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
}
