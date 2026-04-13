import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, PromoDiscountType } from '@prisma/client';
import { normalizePromoCode } from '../promo/promo-code.util';
import { PrismaService } from '../prisma/prisma.service';
import { CreatePromoDto } from './dto/create-promo.dto';
import { PatchPromoDto } from './dto/patch-promo.dto';

@Injectable()
export class StaffPromoService {
  constructor(private readonly prisma: PrismaService) {}

  list() {
    return this.prisma.promoCode.findMany({
      orderBy: { createdAt: 'desc' },
    });
  }

  async create(dto: CreatePromoDto) {
    const code = normalizePromoCode(dto.code);
    if (!code) {
      throw new BadRequestException('Podaj kod.');
    }
    if (dto.discountType === PromoDiscountType.PERCENT) {
      const p = dto.percentOff ?? 0;
      if (p <= 0 || p > 100) {
        throw new BadRequestException('percentOff musi być w zakresie 0–100.');
      }
    } else {
      const f = dto.fixedOff ?? 0;
      if (f <= 0) {
        throw new BadRequestException('fixedOff musi być > 0 dla rabatu kwotowego.');
      }
    }
    return this.prisma.promoCode.create({
      data: {
        code,
        label: dto.label?.trim() || null,
        discountType: dto.discountType,
        percentOff:
          dto.discountType === PromoDiscountType.PERCENT
            ? new Prisma.Decimal((dto.percentOff ?? 0).toFixed(2))
            : null,
        fixedOff:
          dto.discountType === PromoDiscountType.FIXED_AMOUNT
            ? new Prisma.Decimal((dto.fixedOff ?? 0).toFixed(2))
            : null,
        minOrderAmount: new Prisma.Decimal((dto.minOrderAmount ?? 0).toFixed(2)),
        maxUses: dto.maxUses ?? null,
        maxUsesPerUser: dto.maxUsesPerUser ?? 1,
        validFrom: dto.validFrom ? new Date(dto.validFrom) : null,
        validTo: dto.validTo ? new Date(dto.validTo) : null,
        active: dto.active ?? true,
      },
    });
  }

  async patch(id: string, dto: PatchPromoDto) {
    const existing = await this.prisma.promoCode.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('Kod nie istnieje');
    const data: Prisma.PromoCodeUpdateInput = {};
    if (dto.label !== undefined) data.label = dto.label?.trim() || null;
    if (dto.percentOff !== undefined) {
      data.percentOff = new Prisma.Decimal(dto.percentOff.toFixed(2));
    }
    if (dto.fixedOff !== undefined) {
      data.fixedOff = new Prisma.Decimal(dto.fixedOff.toFixed(2));
    }
    if (dto.minOrderAmount !== undefined) {
      data.minOrderAmount = new Prisma.Decimal(dto.minOrderAmount.toFixed(2));
    }
    if (dto.maxUses !== undefined) data.maxUses = dto.maxUses;
    if (dto.maxUsesPerUser !== undefined) data.maxUsesPerUser = dto.maxUsesPerUser;
    if (dto.validFrom !== undefined) data.validFrom = dto.validFrom ? new Date(dto.validFrom) : null;
    if (dto.validTo !== undefined) data.validTo = dto.validTo ? new Date(dto.validTo) : null;
    if (dto.active !== undefined) data.active = dto.active;
    return this.prisma.promoCode.update({
      where: { id },
      data,
    });
  }
}
