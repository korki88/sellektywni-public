import { Injectable, NotFoundException } from '@nestjs/common';
import { ProductStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class StaffProductsService {
  constructor(private readonly prisma: PrismaService) {}

  listPendingApproval() {
    return this.prisma.product.findMany({
      where: { status: ProductStatus.PENDING_APPROVAL },
      orderBy: { createdAt: 'asc' },
    });
  }

  /** Akceptacja rezerwacji — produkt sprzedany. */
  async acceptReservation(productId: string) {
    const p = await this.prisma.product.findUnique({ where: { id: productId } });
    if (!p) throw new NotFoundException('Produkt nie istnieje');
    if (p.status !== ProductStatus.PENDING_APPROVAL) {
      throw new NotFoundException('Produkt nie oczekuje na akceptację');
    }
    return this.prisma.product.update({
      where: { id: productId },
      data: { status: ProductStatus.SOLD },
    });
  }

  /** Odrzucenie — produkt wraca do sprzedaży. */
  async rejectReservation(productId: string) {
    const p = await this.prisma.product.findUnique({ where: { id: productId } });
    if (!p) throw new NotFoundException('Produkt nie istnieje');
    if (p.status !== ProductStatus.PENDING_APPROVAL) {
      throw new NotFoundException('Produkt nie oczekuje na akceptację');
    }
    return this.prisma.product.update({
      where: { id: productId },
      data: { status: ProductStatus.AVAILABLE },
    });
  }
}
