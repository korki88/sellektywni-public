import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { randomBytes } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class StaffGiftCardsService {
  constructor(private readonly prisma: PrismaService) {}

  list() {
    return this.prisma.giftCard.findMany({
      orderBy: { createdAt: 'desc' },
      take: 300,
    });
  }

  private async generateUniqueCode(): Promise<string> {
    for (let i = 0; i < 16; i++) {
      const code = `GIFT-${randomBytes(4).toString('hex').toUpperCase()}`;
      const clash = await this.prisma.giftCard.findUnique({
        where: { code },
      });
      if (!clash) return code;
    }
    return `GIFT-${randomBytes(6).toString('hex').toUpperCase()}`;
  }

  async create(dto: {
    code?: string;
    initialAmount: number;
    currency?: string;
    expiresAt?: Date | null;
    active?: boolean;
  }) {
    const currency = (dto.currency ?? 'PLN').trim().toUpperCase();
    if (currency.length !== 3) {
      throw new BadRequestException('Waluta: 3 znaki ISO');
    }
    const amount = new Prisma.Decimal(dto.initialAmount);
    const raw = dto.code?.trim();
    const code = raw
      ? raw.toUpperCase().replace(/\s+/g, '-')
      : await this.generateUniqueCode();
    const exists = await this.prisma.giftCard.findUnique({ where: { code } });
    if (exists) {
      throw new BadRequestException('Ten kod karty już istnieje');
    }
    return this.prisma.giftCard.create({
      data: {
        code,
        balanceAmount: amount,
        initialAmount: amount,
        currency,
        active: dto.active ?? true,
        expiresAt: dto.expiresAt ?? null,
      },
    });
  }

  async setActive(id: string, active: boolean) {
    return this.prisma.giftCard.update({
      where: { id },
      data: { active },
    });
  }
}
