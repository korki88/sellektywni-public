import {
  Body,
  Controller,
  Get,
  Patch,
  Post,
  Req,
  UnauthorizedException,
} from '@nestjs/common';
import type { Profile } from '@prisma/client';
import type { Request } from 'express';
import { ProfilesService } from '../profiles/profiles.service';
import { NewsletterOptInDto } from './dto/newsletter-opt-in.dto';
import { PreferredLocaleDto } from './dto/preferred-locale.dto';

type ProfileLookupResult = Profile | null;
type PersonalDataExport = Awaited<
  ReturnType<ProfilesService['exportPersonalData']>
>;

@Controller('auth')
export class AuthController {
  constructor(private readonly profiles: ProfilesService) {}

  /**
   * Aktualny profil (rola RBAC) na podstawie Bearer JWT — bez wymogu wcześniejszego middleware profilu.
   */
  @Get('me')
  async me(@Req() req: Request): Promise<{ profile: ProfileLookupResult }> {
    const jwtPayload = req.supabaseJwt;
    if (!jwtPayload) {
      throw new UnauthorizedException();
    }
    const profile = await this.profiles.findByUserId(jwtPayload.sub);
    return { profile };
  }

  /**
   * Wywołaj z klienta zaraz po pierwszym zalogowaniu przez Google (access token Supabase w Bearer).
   */
  @Post('profile/bootstrap-google')
  async bootstrapGoogle(@Req() req: Request): Promise<Profile> {
    const jwtPayload = req.supabaseJwt;
    if (!jwtPayload) {
      throw new UnauthorizedException();
    }
    return this.profiles.ensureBronzeCustomerOnGoogleSignup(jwtPayload);
  }

  /**
   * Po rejestracji/logowaniu e-mail: utwórz profil sklepu, jeśli nie istnieje (CUSTOMER / BRONZE).
   */
  @Post('profile/ensure')
  async ensureProfile(@Req() req: Request): Promise<Profile> {
    const jwtPayload = req.supabaseJwt;
    if (!jwtPayload) {
      throw new UnauthorizedException();
    }
    return this.profiles.ensureCustomerProfileIfMissing(jwtPayload);
  }

  /** Zgoda marketingowa (newsletter / oferty). */
  @Patch('me/newsletter')
  async patchNewsletter(
    @Body() dto: NewsletterOptInDto,
    @Req() req: Request,
  ): Promise<{ profile: Profile }> {
    const jwtPayload = req.supabaseJwt;
    if (!jwtPayload) {
      throw new UnauthorizedException();
    }
    await this.profiles.ensureCustomerProfileIfMissing(jwtPayload);
    const profile = await this.profiles.updateNewsletterOptIn(
      jwtPayload.sub,
      dto.optIn,
    );
    return { profile };
  }

  /** Preferowany język UI (np. pl, en). */
  @Patch('me/locale')
  async patchLocale(
    @Body() dto: PreferredLocaleDto,
    @Req() req: Request,
  ): Promise<{ profile: Profile }> {
    const jwtPayload = req.supabaseJwt;
    if (!jwtPayload) {
      throw new UnauthorizedException();
    }
    await this.profiles.ensureCustomerProfileIfMissing(jwtPayload);
    const profile = await this.profiles.updatePreferredLocale(
      jwtPayload.sub,
      dto.locale,
    );
    return { profile };
  }

  /** Eksport danych osobowych (RODO) — JSON. */
  @Get('me/data-export')
  async dataExport(@Req() req: Request): Promise<PersonalDataExport> {
    const jwtPayload = req.supabaseJwt;
    if (!jwtPayload) {
      throw new UnauthorizedException();
    }
    return this.profiles.exportPersonalData(jwtPayload.sub);
  }
}
