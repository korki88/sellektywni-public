import { randomBytes } from 'crypto';
import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { ProfileRank, ProfileRole, type Profile } from '@prisma/client';
import { defaultPermissionsForRole } from '../auth/permissions';
import { PrismaService } from '../prisma/prisma.service';
import type { SupabaseJwtPayload } from '../types/express';

@Injectable()
export class ProfilesService {
  private readonly log = new Logger(ProfilesService.name);

  constructor(private readonly prisma: PrismaService) {}

  private async generateUniqueReferralCode(): Promise<string> {
    for (let i = 0; i < 12; i++) {
      const code = randomBytes(4).toString('hex').toUpperCase();
      const clash = await this.prisma.profile.findUnique({
        where: { referralCode: code },
      });
      if (!clash) return code;
    }
    return `${randomBytes(6).toString('hex').toUpperCase()}`;
  }

  findByUserId(userId: string) {
    return this.prisma.profile.findUnique({ where: { userId } });
  }

  async updatePreferredLocale(userId: string, locale: string) {
    const l = locale.trim().toLowerCase().slice(0, 12);
    if (l.length < 2) {
      throw new BadRequestException('Nieprawidłowy kod języka');
    }
    return this.prisma.profile.update({
      where: { userId },
      data: { preferredLocale: l },
    });
  }

  /**
   * Rejestracja e-mail / dowolny provider: tworzy profil CUSTOMER jeśli go brak.
   */
  async ensureCustomerProfileIfMissing(
    jwtPayload: SupabaseJwtPayload,
  ): Promise<Profile> {
    const existing = await this.prisma.profile.findUnique({
      where: { userId: jwtPayload.sub },
    });
    if (existing) {
      if (!existing.referralCode) {
        const code = await this.generateUniqueReferralCode();
        return this.prisma.profile.update({
          where: { userId: jwtPayload.sub },
          data: { referralCode: code },
        });
      }
      return existing;
    }
    const refCode = await this.generateUniqueReferralCode();
    const created = await this.prisma.profile.create({
      data: {
        userId: jwtPayload.sub,
        email: jwtPayload.email ?? null,
        role: ProfileRole.CUSTOMER,
        permissions: defaultPermissionsForRole(ProfileRole.CUSTOMER),
        points: 0,
        rank: ProfileRank.BRONZE,
        referralCode: refCode,
      },
    });
    this.log.log(`Utworzono profil (ensure) dla ${jwtPayload.sub}`);
    return created;
  }

  /**
   * Pierwsze logowanie przez Google: tworzy profil CUSTOMER / BRONZE / 0 pkt.
   * Idempotentne — kolejne wywołania zwracają istniejący profil.
   */
  async ensureBronzeCustomerOnGoogleSignup(
    jwtPayload: SupabaseJwtPayload,
  ): Promise<Profile> {
    if (!this.isGoogleSession(jwtPayload.app_metadata)) {
      throw new BadRequestException(
        'Profil można utworzyć tylko dla sesji zalogowanej przez Google.',
      );
    }

    const existing = await this.prisma.profile.findUnique({
      where: { userId: jwtPayload.sub },
    });
    if (existing) {
      if (!existing.referralCode) {
        const code = await this.generateUniqueReferralCode();
        return this.prisma.profile.update({
          where: { userId: jwtPayload.sub },
          data: { referralCode: code },
        });
      }
      return existing;
    }

    const refCode = await this.generateUniqueReferralCode();
    const created = await this.prisma.profile.create({
      data: {
        userId: jwtPayload.sub,
        email: jwtPayload.email ?? null,
        role: ProfileRole.CUSTOMER,
        permissions: defaultPermissionsForRole(ProfileRole.CUSTOMER),
        points: 0,
        rank: ProfileRank.BRONZE,
        referralCode: refCode,
      },
    });
    this.log.log(`Utworzono profil BRONZE dla użytkownika ${jwtPayload.sub}`);
    return created;
  }

  private isGoogleSession(appMetadata: unknown): boolean {
    if (!appMetadata || typeof appMetadata !== 'object') return false;
    const m = appMetadata as Record<string, unknown>;
    if (m.provider === 'google') return true;
    const providers = m.providers;
    return Array.isArray(providers) && providers.some((p) => p === 'google');
  }

  async updateNewsletterOptIn(
    userId: string,
    optIn: boolean,
  ): Promise<Profile> {
    return this.prisma.profile.update({
      where: { userId },
      data: { newsletterOptIn: optIn },
    });
  }

  /**
   * Eksport danych osobowych (RODO art. 20) — zbiór powiązanych rekordów użytkownika.
   */
  async exportPersonalData(userId: string) {
    const [
      profile,
      orders,
      addresses,
      wishlist,
      reviews,
      watches,
      returns,
      checkoutPref,
    ] = await Promise.all([
      this.prisma.profile.findUnique({ where: { userId } }),
      this.prisma.customerOrder.findMany({
        where: { userId },
        include: {
          items: true,
          promoCode: { select: { code: true } },
        },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.addressBookEntry.findMany({
        where: { userId },
        orderBy: { updatedAt: 'desc' },
      }),
      this.prisma.wishlistItem.findMany({
        where: { userId },
        include: { product: { select: { name: true, idDotykacka: true } } },
      }),
      this.prisma.productReview.findMany({ where: { userId } }),
      this.prisma.availabilityWatch.findMany({
        where: { userId },
        include: { product: { select: { name: true } } },
      }),
      this.prisma.returnRequest.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.checkoutPreference.findUnique({
        where: { userId },
      }),
    ]);

    const redemptions = await this.prisma.promoRedemption.findMany({
      where: { userId },
      include: { promoCode: { select: { code: true } } },
    });

    const dec = (v: { toString(): string } | null | undefined) =>
      v == null ? null : v.toString();

    return {
      exportedAt: new Date().toISOString(),
      profile: profile
        ? {
            userId: profile.userId,
            email: profile.email,
            role: profile.role,
            points: profile.points,
            rank: profile.rank,
            newsletterOptIn: profile.newsletterOptIn,
            preferredLocale: profile.preferredLocale,
            referralCode: profile.referralCode,
            customerSegment: profile.customerSegment,
            createdAt: profile.createdAt,
            updatedAt: profile.updatedAt,
          }
        : null,
      orders: orders.map((o) => ({
        id: o.id,
        status: o.status,
        subtotalAmount: dec(o.subtotalAmount),
        discountAmount: dec(o.discountAmount),
        giftCardDiscountAmount: dec(o.giftCardDiscountAmount),
        referralDiscountAmount: dec(o.referralDiscountAmount),
        totalAmount: dec(o.totalAmount),
        promoCode: o.promoCode?.code ?? null,
        paymentMethod: o.paymentMethod,
        paymentStatus: o.paymentStatus,
        shippingMethod: o.shippingMethod,
        createdAt: o.createdAt,
        items: o.items.map((i) => ({
          productId: i.productId,
          name: i.name,
          quantity: i.quantity,
          price: dec(i.price),
          lineTotal: dec(i.lineTotal),
        })),
      })),
      addressBook: addresses.map((a) => ({
        id: a.id,
        label: a.label,
        entryType: a.entryType,
        country: a.country,
        city: a.city,
        postalCode: a.postalCode,
        street: a.street,
        isDefault: a.isDefault,
        updatedAt: a.updatedAt,
      })),
      wishlist: wishlist.map((w) => ({
        productId: w.productId,
        productName: w.product.name,
        createdAt: w.createdAt,
      })),
      productReviews: reviews.map((r) => ({
        productId: r.productId,
        rating: r.rating,
        comment: r.comment,
        createdAt: r.createdAt,
      })),
      availabilityWatches: watches.map((w) => ({
        productId: w.productId,
        productName: w.product.name,
        updatedAt: w.updatedAt,
      })),
      returnRequests: returns.map((r) => ({
        id: r.id,
        orderId: r.orderId,
        reason: r.reason,
        status: r.status,
        createdAt: r.createdAt,
      })),
      checkoutPreferences: checkoutPref,
      promoRedemptions: redemptions.map((r) => ({
        promoCode: r.promoCode.code,
        orderId: r.orderId,
        createdAt: r.createdAt,
      })),
    };
  }
}
