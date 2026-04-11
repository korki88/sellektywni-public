import {
  BadRequestException,
  Injectable,
  Logger,
} from '@nestjs/common';
import { ProfileRank, ProfileRole, type Profile } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import type { SupabaseJwtPayload } from '../types/express';

@Injectable()
export class ProfilesService {
  private readonly log = new Logger(ProfilesService.name);

  constructor(private readonly prisma: PrismaService) {}

  findByUserId(userId: string) {
    return this.prisma.profile.findUnique({ where: { userId } });
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
      return existing;
    }
    const created = await this.prisma.profile.create({
      data: {
        userId: jwtPayload.sub,
        email: jwtPayload.email ?? null,
        role: ProfileRole.CUSTOMER,
        points: 0,
        rank: ProfileRank.BRONZE,
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
      return existing;
    }

    const created = await this.prisma.profile.create({
      data: {
        userId: jwtPayload.sub,
        email: jwtPayload.email ?? null,
        role: ProfileRole.CUSTOMER,
        points: 0,
        rank: ProfileRank.BRONZE,
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
    return (
      Array.isArray(providers) &&
      providers.some((p) => p === 'google')
    );
  }
}
