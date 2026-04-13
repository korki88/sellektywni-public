import { Injectable, NotFoundException } from '@nestjs/common';
import { ProductStatus, ReservationStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class StaffProductsService {
  constructor(private readonly prisma: PrismaService) {}

  private userIdFromOwnerKey(ownerKey: string): string | null {
    if (!ownerKey.startsWith('user:')) {
      return null;
    }
    const userId = ownerKey.slice('user:'.length).trim();
    return userId.length > 0 ? userId : null;
  }

  async listPendingApproval() {
    const products = await this.prisma.product.findMany({
      where: {
        reservations: {
          some: { status: ReservationStatus.PENDING },
        },
      },
      orderBy: { createdAt: 'asc' },
      include: {
        reservations: {
          where: { status: ReservationStatus.PENDING },
          select: { quantity: true },
        },
      },
    });
    return products.map(({ reservations, ...p }) => {
      const finalQuantity = reservations.reduce((s, r) => s + r.quantity, 0);
      return {
        ...p,
        // Backward compatibility: stare rekordy PENDING_APPROVAL bez rezerwacji.
        pendingQuantity: finalQuantity > 0 ? finalQuantity : 1,
      };
    });
  }

  /** Akceptacja rezerwacji — produkt sprzedany. */
  async acceptReservation(productId: string) {
    const p = await this.prisma.product.findUnique({
      where: { id: productId },
    });
    if (!p) throw new NotFoundException('Produkt nie istnieje');
    const pendingRows = await this.prisma.productReservation.findMany({
      where: { productId, status: ReservationStatus.PENDING },
      select: { quantity: true },
    });
    const pendingQty = pendingRows.reduce((sum, r) => sum + r.quantity, 0);
    if (pendingQty <= 0) {
      throw new NotFoundException('Produkt nie oczekuje na akceptację');
    }
    const newStock = Math.max(0, p.stockQty - pendingQty);
    const inCartRows = await this.prisma.productReservation.findMany({
      where: { productId, status: ReservationStatus.IN_CART },
      select: { quantity: true },
    });
    const inCartQty = inCartRows.reduce((sum, r) => sum + r.quantity, 0);
    const nextStatus =
      newStock <= 0
        ? ProductStatus.SOLD
        : newStock - inCartQty <= 0
          ? ProductStatus.RESERVED
          : ProductStatus.AVAILABLE;
    const [updated] = await this.prisma.$transaction([
      this.prisma.product.update({
        where: { id: productId },
        data: {
          stockQty: newStock,
          status: nextStatus,
        },
      }),
      this.prisma.productReservation.updateMany({
        where: { productId, status: ReservationStatus.PENDING },
        data: { status: ReservationStatus.ACCEPTED },
      }),
    ]);
    return {
      ...updated,
      pendingQuantity: 0,
    };
  }

  /** Odrzucenie — produkt wraca do sprzedaży. */
  async rejectReservation(productId: string) {
    const p = await this.prisma.product.findUnique({
      where: { id: productId },
    });
    if (!p) throw new NotFoundException('Produkt nie istnieje');
    const pendingRows = await this.prisma.productReservation.findMany({
      where: { productId, status: ReservationStatus.PENDING },
      select: { quantity: true, ownerKey: true },
    });
    const pendingQty = pendingRows.reduce((sum, r) => sum + r.quantity, 0);
    if (pendingQty <= 0) {
      throw new NotFoundException('Produkt nie oczekuje na akceptację');
    }
    const updated = await this.prisma.$transaction(async (tx) => {
      const changedAt = new Date();
      await tx.productReservation.updateMany({
        where: { productId, status: ReservationStatus.PENDING },
        data: { status: ReservationStatus.REJECTED, updatedAt: changedAt },
      });
      for (const row of pendingRows) {
        const userId = this.userIdFromOwnerKey(row.ownerKey);
        if (!userId) continue;
        await tx.availabilityWatch.upsert({
          where: {
            userId_productId: { userId, productId },
          },
          create: { userId, productId },
          update: {},
        });
      }
      return tx.product.update({
        where: { id: productId },
        data: { status: ProductStatus.RESERVED },
      });
    });
    return {
      ...updated,
      pendingQuantity: 0,
    };
  }
}
