import { Injectable, NotFoundException } from '@nestjs/common';
import { CustomerOrderStatus, PaymentStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class StaffOrdersService {
  constructor(private readonly prisma: PrismaService) {}

  async listOrders() {
    const orders = await this.prisma.customerOrder.findMany({
      include: { items: true },
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
    const ids = [...new Set(orders.map((o) => o.userId))];
    const profiles = await this.prisma.profile.findMany({
      where: { userId: { in: ids } },
      select: { userId: true, email: true },
    });
    const byUser = new Map(profiles.map((p) => [p.userId, p]));
    return orders.map((o) => ({
      id: o.id,
      userId: o.userId,
      customerEmail: byUser.get(o.userId)?.email ?? null,
      createdAt: o.createdAt,
      status: o.status,
      totalAmount: o.totalAmount,
      paymentMethod: o.paymentMethod,
      paymentProvider: o.paymentProvider,
      paymentStatus: o.paymentStatus,
      paymentReference: o.paymentReference,
      itemCount: o.items.reduce((sum, i) => sum + i.quantity, 0),
      items: o.items.map((i) => ({
        productId: i.productId,
        name: i.name,
        quantity: i.quantity,
        price: i.price,
        lineTotal: i.lineTotal,
      })),
    }));
  }

  async updateOrderStatus(orderId: string, status: CustomerOrderStatus) {
    const exists = await this.prisma.customerOrder.findUnique({
      where: { id: orderId },
      select: { id: true },
    });
    if (!exists) throw new NotFoundException('Zamówienie nie istnieje');
    return this.prisma.customerOrder.update({
      where: { id: orderId },
      data: { status },
      include: { items: true },
    });
  }

  async updatePaymentStatus(orderId: string, paymentStatus: PaymentStatus) {
    const exists = await this.prisma.customerOrder.findUnique({
      where: { id: orderId },
      select: { id: true },
    });
    if (!exists) throw new NotFoundException('Zamówienie nie istnieje');
    return this.prisma.customerOrder.update({
      where: { id: orderId },
      data: { paymentStatus },
      include: { items: true },
    });
  }
}
