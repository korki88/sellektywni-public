import {
  Controller,
  Get,
  Post,
  Req,
  UnauthorizedException,
} from '@nestjs/common';
import type { Request } from 'express';
import { ProfilesService } from '../profiles/profiles.service';

@Controller('auth')
export class AuthController {
  constructor(private readonly profiles: ProfilesService) {}

  /**
   * Aktualny profil (rola RBAC) na podstawie Bearer JWT — bez wymogu wcześniejszego middleware profilu.
   */
  @Get('me')
  async me(@Req() req: Request) {
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
  async bootstrapGoogle(@Req() req: Request) {
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
  async ensureProfile(@Req() req: Request) {
    const jwtPayload = req.supabaseJwt;
    if (!jwtPayload) {
      throw new UnauthorizedException();
    }
    return this.profiles.ensureCustomerProfileIfMissing(jwtPayload);
  }
}
