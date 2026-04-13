import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class StaffReviewsService {
  constructor(private readonly prisma: PrismaService) {}

  async listRecentPendingModeration() {
    return this.prisma.productReview.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: {
        product: { select: { id: true, name: true } },
      },
    });
  }

  async setVisible(reviewId: string, isVisible: boolean) {
    const r = await this.prisma.productReview.findUnique({
      where: { id: reviewId },
    });
    if (!r) throw new NotFoundException('Opinia nie istnieje');
    return this.prisma.productReview.update({
      where: { id: reviewId },
      data: { isVisible },
      include: {
        product: { select: { id: true, name: true } },
      },
    });
  }
}
