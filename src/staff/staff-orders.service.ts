import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { CustomerOrderStatus, PaymentStatus } from '@prisma/client';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';

type AuditActor = {
  userId: string;
  userEmail?: string | null;
  ipAddress?: string | null;
};

@Injectable()
export class StaffOrdersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  private parseOrderStatusFilter(
    raw?: string,
  ): CustomerOrderStatus | undefined {
    if (!raw?.trim()) {
      return undefined;
    }
    const u = raw.trim().toUpperCase();
    return (Object.values(CustomerOrderStatus) as string[]).includes(u)
      ? (u as CustomerOrderStatus)
      : undefined;
  }

  async listOrders(statusFilter?: string) {
    const status = this.parseOrderStatusFilter(statusFilter);
    const orders = await this.prisma.customerOrder.findMany({
      where: status ? { status } : undefined,
      include: {
        items: true,
        staffNotes: { orderBy: { createdAt: 'desc' }, take: 1 },
      },
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
      shippingMethod: o.shippingMethod,
      paymentMethod: o.paymentMethod,
      paymentProvider: o.paymentProvider,
      paymentStatus: o.paymentStatus,
      paymentReference: o.paymentReference,
      customerNote: o.customerNote,
      staffNotePreview:
        o.staffNotes[0]?.body != null
          ? String(o.staffNotes[0].body).slice(0, 160)
          : null,
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

  async getOrderDetail(orderId: string) {
    const o = await this.prisma.customerOrder.findUnique({
      where: { id: orderId },
      include: {
        items: true,
        staffNotes: { orderBy: { createdAt: 'asc' } },
        promoCode: { select: { code: true, label: true } },
      },
    });
    if (!o) {
      throw new NotFoundException('Zamówienie nie istnieje');
    }
    const authorIds = [...new Set(o.staffNotes.map((n) => n.authorUserId))];
    const profs = await this.prisma.profile.findMany({
      where: { userId: { in: authorIds } },
      select: { userId: true, email: true },
    });
    const byUid = new Map(profs.map((p) => [p.userId, p.email]));
    const cust = await this.prisma.profile.findUnique({
      where: { userId: o.userId },
      select: { email: true, userId: true },
    });
    return {
      id: o.id,
      userId: o.userId,
      customerEmail: cust?.email ?? null,
      createdAt: o.createdAt,
      updatedAt: o.updatedAt,
      status: o.status,
      customerNote: o.customerNote,
      subtotalAmount: o.subtotalAmount,
      discountAmount: o.discountAmount,
      totalAmount: o.totalAmount,
      giftCardDiscountAmount: o.giftCardDiscountAmount,
      referralDiscountAmount: o.referralDiscountAmount,
      promoCode: o.promoCode?.code ?? null,
      paymentMethod: o.paymentMethod,
      paymentProvider: o.paymentProvider,
      paymentStatus: o.paymentStatus,
      paymentReference: o.paymentReference,
      paymentSessionUrl: o.paymentSessionUrl,
      shippingMethod: o.shippingMethod,
      shippingSnapshot: o.shippingSnapshot,
      items: o.items,
      staffNotes: o.staffNotes.map((n) => ({
        id: n.id,
        body: n.body,
        createdAt: n.createdAt,
        authorUserId: n.authorUserId,
        authorEmail: byUid.get(n.authorUserId) ?? null,
      })),
    };
  }

  async addStaffNote(orderId: string, authorUserId: string, body: string) {
    const b = body.trim();
    if (b.length === 0) {
      throw new BadRequestException('Treść notatki jest wymagana');
    }
    const o = await this.prisma.customerOrder.findUnique({
      where: { id: orderId },
      select: { id: true },
    });
    if (!o) {
      throw new NotFoundException('Zamówienie nie istnieje');
    }
    return this.prisma.orderStaffNote.create({
      data: {
        orderId,
        authorUserId,
        body: b.slice(0, 4000),
      },
    });
  }

  async updateOrderStatus(
    orderId: string,
    status: CustomerOrderStatus,
    actor: AuditActor,
  ) {
    const exists = await this.prisma.customerOrder.findUnique({
      where: { id: orderId },
      select: { id: true, status: true },
    });
    if (!exists) throw new NotFoundException('Zamówienie nie istnieje');
    const updated = await this.prisma.customerOrder.update({
      where: { id: orderId },
      data: { status },
      include: { items: true },
    });
    await this.audit.logAction({
      userId: actor.userId,
      userEmail:
        actor.userEmail?.trim() || `user-${actor.userId}@unknown.local`,
      action: 'CHANGE_ORDER_STATUS',
      resourceType: 'ORDER',
      resourceId: orderId,
      oldValue: { status: exists.status },
      newValue: { status: updated.status },
      ipAddress: actor.ipAddress ?? null,
    });
    return updated;
  }

  async updatePaymentStatus(
    orderId: string,
    paymentStatus: PaymentStatus,
    actor: AuditActor,
  ) {
    const exists = await this.prisma.customerOrder.findUnique({
      where: { id: orderId },
      select: { id: true, paymentStatus: true },
    });
    if (!exists) throw new NotFoundException('Zamówienie nie istnieje');
    const updated = await this.prisma.customerOrder.update({
      where: { id: orderId },
      data: { paymentStatus },
      include: { items: true },
    });
    await this.audit.logAction({
      userId: actor.userId,
      userEmail:
        actor.userEmail?.trim() || `user-${actor.userId}@unknown.local`,
      action: 'CHANGE_ORDER_PAYMENT_STATUS',
      resourceType: 'ORDER',
      resourceId: orderId,
      oldValue: { paymentStatus: exists.paymentStatus },
      newValue: { paymentStatus: updated.paymentStatus },
      ipAddress: actor.ipAddress ?? null,
    });
    return updated;
  }
}
