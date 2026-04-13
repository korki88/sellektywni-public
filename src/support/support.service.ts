import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class SupportService {
  constructor(private readonly prisma: PrismaService) {}

  async createTicket(userId: string, subject: string, body: string) {
    const s = subject.trim();
    const b = body.trim();
    if (s.length < 3) {
      throw new BadRequestException('Podaj temat');
    }
    if (b.length < 5) {
      throw new BadRequestException('Podaj treść wiadomości');
    }
    return this.prisma.$transaction(async (tx) => {
      const t = await tx.supportTicket.create({
        data: { userId, subject: s },
      });
      await tx.supportMessage.create({
        data: {
          ticketId: t.id,
          authorUserId: userId,
          body: b,
          isStaff: false,
        },
      });
      return tx.supportTicket.findUnique({
        where: { id: t.id },
        include: { messages: { orderBy: { createdAt: 'asc' } } },
      });
    });
  }

  listMyTickets(userId: string) {
    return this.prisma.supportTicket.findMany({
      where: { userId },
      orderBy: { updatedAt: 'desc' },
      include: {
        messages: { orderBy: { createdAt: 'asc' }, take: 5 },
      },
    });
  }

  async getTicket(userId: string, ticketId: string) {
    const t = await this.prisma.supportTicket.findFirst({
      where: { id: ticketId, userId },
      include: { messages: { orderBy: { createdAt: 'asc' } } },
    });
    if (!t) throw new NotFoundException();
    return t;
  }

  async addCustomerMessage(userId: string, ticketId: string, body: string) {
    const t = await this.prisma.supportTicket.findFirst({
      where: { id: ticketId, userId },
    });
    if (!t) throw new NotFoundException();
    const b = body.trim();
    if (b.length < 1) throw new BadRequestException('Pusta wiadomość');
    return this.prisma.supportMessage.create({
      data: {
        ticketId,
        authorUserId: userId,
        body: b,
        isStaff: false,
      },
    });
  }

  listAllForStaff() {
    return this.prisma.supportTicket.findMany({
      orderBy: { updatedAt: 'desc' },
      include: {
        messages: { orderBy: { createdAt: 'desc' }, take: 1 },
      },
      take: 200,
    });
  }

  getTicketForStaff(ticketId: string) {
    return this.prisma.supportTicket.findUnique({
      where: { id: ticketId },
      include: { messages: { orderBy: { createdAt: 'asc' } } },
    });
  }

  async addStaffMessage(ticketId: string, body: string, staffUserId: string) {
    const t = await this.prisma.supportTicket.findUnique({
      where: { id: ticketId },
    });
    if (!t) throw new NotFoundException();
    const b = body.trim();
    if (b.length < 1) throw new BadRequestException('Pusta wiadomość');
    return this.prisma.$transaction(async (tx) => {
      await tx.supportMessage.create({
        data: {
          ticketId,
          authorUserId: staffUserId,
          body: b,
          isStaff: true,
        },
      });
      return tx.supportTicket.update({
        where: { id: ticketId },
        data: { status: 'ANSWERED' },
        include: { messages: { orderBy: { createdAt: 'asc' } } },
      });
    });
  }
}
