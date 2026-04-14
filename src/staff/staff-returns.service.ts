import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateReturnRequestDto } from './dto/update-return-request.dto';

@Injectable()
export class StaffReturnsService {
  constructor(private readonly prisma: PrismaService) {}

  listReturns() {
    return this.prisma.returnRequest.findMany({
      orderBy: { createdAt: 'desc' },
      include: {
        order: {
          select: {
            id: true,
            userId: true,
            status: true,
            totalAmount: true,
            createdAt: true,
          },
        },
      },
    });
  }

  async updateReturn(id: string, dto: UpdateReturnRequestDto) {
    const existing = await this.prisma.returnRequest.findUnique({
      where: { id },
    });
    if (!existing) {
      throw new NotFoundException('Wniosek o zwrot nie istnieje');
    }
    return this.prisma.returnRequest.update({
      where: { id },
      data: {
        status: dto.status,
        ...(dto.staffNote !== undefined
          ? { staffNote: dto.staffNote.trim() || null }
          : {}),
      },
      include: {
        order: {
          select: {
            id: true,
            userId: true,
            status: true,
            totalAmount: true,
            createdAt: true,
          },
        },
      },
    });
  }
}
