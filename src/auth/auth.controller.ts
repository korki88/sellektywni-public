import {
  Controller,
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
}
