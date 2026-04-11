import { Injectable, NestMiddleware } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class LoadProfileMiddleware implements NestMiddleware {
  constructor(private readonly prisma: PrismaService) {}

  async use(req: Request, _res: Response, next: NextFunction): Promise<void> {
    const sub = req.supabaseJwt?.sub;
    if (!sub) {
      next();
      return;
    }
    const profile = await this.prisma.profile.findUnique({
      where: { userId: sub },
    });
    req.profile = profile ?? undefined;
    next();
  }
}
