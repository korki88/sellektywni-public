import {
  Injectable,
  NestMiddleware,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { NextFunction, Request, Response } from 'express';
import * as jwt from 'jsonwebtoken';

@Injectable()
export class SupabaseJwtMiddleware implements NestMiddleware {
  constructor(private readonly config: ConfigService) {}

  use(req: Request, _res: Response, next: NextFunction): void {
    const secret = this.config.get<string>('SUPABASE_JWT_SECRET');
    if (!secret) {
      throw new UnauthorizedException('SUPABASE_JWT_SECRET is not configured');
    }

    const auth = req.headers.authorization;
    const token = auth?.startsWith('Bearer ') ? auth.slice(7).trim() : null;
    if (!token) {
      throw new UnauthorizedException('Brak nagłówka Authorization: Bearer <token>');
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
