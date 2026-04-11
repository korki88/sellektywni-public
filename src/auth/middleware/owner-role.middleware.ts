import {
  ForbiddenException,
  Injectable,
  NestMiddleware,
} from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import type { NextFunction, Request, Response } from 'express';

@Injectable()
export class OwnerRoleMiddleware implements NestMiddleware {
  use(req: Request, _res: Response, next: NextFunction): void {
    const p = req.profile;
    if (!p || p.role !== ProfileRole.OWNER) {
      throw new ForbiddenException('Wymagana rola OWNER');
    }
    next();
  }
}
