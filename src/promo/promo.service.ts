import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma, PromoDiscountType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { normalizePromoCode } from './promo-code.util';

export type PromoApplyResult = {
  promoId: string;
  /** Kod do wyświetlenia (jak w bazie). */
  code: string;
  discountAmount: Prisma.Decimal;
};

@Injectable()
export class PromoService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Oblicza kwotę rabatu (bez modyfikacji bazy). subtotal — suma pozycji przed rabatem.
   */
  async computeDiscountForSubtotal(
    codeRaw: string,
    userId: string,
    subtotal: number,
  ): Promise<PromoApplyResult | null> {
    const code = normalizePromoCode(codeRaw);
    if (!code) return null;
    const promo = await this.prisma.promoCode.findUnique({ where: { code } });
    if (!promo || !promo.active) {
      throw new BadRequestException(
        'Nieprawidłowy lub nieaktywny kod promocyjny.',
      );
    }
    const now = new Date();
    if (promo.validFrom && now < promo.validFrom) {
      throw new BadRequestException(
        'Ten kod promocyjny nie jest jeszcze aktywny.',
      );
    }
    if (promo.validTo && now > promo.validTo) {
      throw new BadRequestException('Ten kod promocyjny wygasł.');
    }
    if (Number(promo.minOrderAmount) > subtotal + 1e-6) {
      throw new BadRequestException(
        `Minimalna wartość zamówienia dla tego kodu to ${promo.minOrderAmount.toString()} zł.`,
      );
    }
    if (promo.maxUses != null && promo.usesCount >= promo.maxUses) {
      throw new BadRequestException(
        'Wykorzystano limit użyć tego kodu promocyjnego.',
      );
    }
    const userRedemptions = await this.prisma.promoRedemption.count({
      where: { userId, promoCodeId: promo.id },
    });
    if (userRedemptions >= promo.maxUsesPerUser) {
      throw new BadRequestException(
        'Wykorzystałeś już ten kod przy wcześniejszym zamówieniu.',
      );
    }

    let discount = 0;
    if (promo.discountType === PromoDiscountType.PERCENT) {
      const p = promo.percentOff ? Number(promo.percentOff) : 0;
      if (p <= 0 || p > 100) {
        throw new BadRequestException(
          'Błędna konfiguracja kodu rabatowego (procent).',
        );
      }
      discount = Math.round(subtotal * (p / 100) * 100) / 100;
    } else {
      const f = promo.fixedOff ? Number(promo.fixedOff) : 0;
      if (f <= 0) {
        throw new BadRequestException(
          'Błędna konfiguracja kodu rabatowego (kwota).',
        );
      }
      discount = Math.min(f, subtotal);
    }
    discount = Math.round(discount * 100) / 100;
    if (discount <= 0) {
      throw new BadRequestException('Rabat z tego kodu wynosi 0 zł.');
    }

    return {
      promoId: promo.id,
      code: promo.code,
      discountAmount: new Prisma.Decimal(discount.toFixed(2)),
    };
  }
}
