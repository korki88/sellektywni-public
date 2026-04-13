import {
  Injectable,
  NestMiddleware,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ProfileRole } from '@prisma/client';
import type { NextFunction, Request, Response } from 'express';
import * as jwt from 'jsonwebtoken';

import {
  DEV_MOCK_BEARER_PREFIX,
  DEV_MOCK_PROFILES,
} from '../dev-mock.constants';

@Injectable()
export class SupabaseJwtMiddleware implements NestMiddleware {
  constructor(private readonly config: ConfigService) {}

  use(req: Request, _res: Response, next: NextFunction): void {
    const auth = req.headers.authorization;
    const token = auth?.startsWith('Bearer ') ? auth.slice(7).trim() : null;
    if (!token) {
      throw new UnauthorizedException(
        'Brak nagłówka Authorization: Bearer <token>',
      );
    }

    const mockEnabled =
      this.config.get<string>('AUTH_DEV_MOCK') === 'true' ||
      this.config.get<string>('AUTH_DEV_MOCK') === '1';

    if (mockEnabled && token.startsWith(DEV_MOCK_BEARER_PREFIX)) {
      const roleKey = token.slice(DEV_MOCK_BEARER_PREFIX.length).trim();
      const role = roleKey as ProfileRole;
      const mock = DEV_MOCK_PROFILES[role];
      if (!mock) {
        throw new UnauthorizedException(
          `Nieznana rola dev-mock: ${roleKey} (OWNER | STAFF | CUSTOMER)`,
        );
      }
      req.supabaseJwt = {
        sub: mock.userId,
        email: mock.email,
        app_metadata: { provider: 'dev-mock', role },
      };
      next();
      return;
    }

    const secret = this.config.get<string>('SUPABASE_JWT_SECRET');
    if (!secret) {
      throw new UnauthorizedException('SUPABASE_JWT_SECRET is not configured');
    }

    try {
      const decoded = jwt.verify(token, secret, {
        algorithms: ['HS256'],
      }) as jwt.JwtPayload & { app_metadata?: unknown };

      if (!decoded.sub || typeof decoded.sub !== 'string') {
        throw new UnauthorizedException('Token bez poprawnego sub');
      }

      req.supabaseJwt = {
        sub: decoded.sub,
        email: typeof decoded.email === 'string' ? decoded.email : undefined,
        app_metadata: decoded.app_metadata,
      };
      next();
    } catch (e) {
      if (e instanceof UnauthorizedException) throw e;
      throw new UnauthorizedException('Nieprawidłowy lub wygasły token');
    }
  }
}
