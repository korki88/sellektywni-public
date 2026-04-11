import {
  ForbiddenException,
  Injectable,
  NestMiddleware,
} from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import type { NextFunction, Request, Response } from 'express';

/**
 * Dostęp wyłącznie dla STAFF. OWNER nie przechodzi — jeśli właściciel ma korzystać
 * z tych samych endpointów, rozszerz warunek o ProfileRole.OWNER.
 */
@Injectable()
export class StaffRoleMiddleware implements NestMiddleware {
  use(req: Request, _res: Response, next: NextFunction): void {
    const p = req.profile;
    if (!p || p.role !== ProfileRole.STAFF) {
      throw new ForbiddenException('Wymagana rola STAFF');
    }
    next();
  }
}
