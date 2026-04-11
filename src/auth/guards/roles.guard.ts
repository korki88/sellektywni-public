import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ProfileRole } from '@prisma/client';
import type { Request } from 'express';
import { MIN_ROLE_KEY } from '../decorators/minimum-role.decorator';
import { ROLES_KEY } from '../decorators/roles.decorator';

/** Poziomy RBAC: OWNER — pełny; STAFF — operacje sklepowe; CUSTOMER — zakupy (ścieżki „tylko klient”). */
const ROLE_RANK: Record<ProfileRole, number> = {
  [ProfileRole.CUSTOMER]: 0,
  [ProfileRole.STAFF]: 1,
  [ProfileRole.OWNER]: 2,
};

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const req = context.switchToHttp().getRequest<Request>();
    const profile = req.profile;

    const minRole = this.reflector.getAllAndOverride<ProfileRole | undefined>(
      MIN_ROLE_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (minRole !== undefined) {
      if (!profile) {
        throw new ForbiddenException('Brak profilu użytkownika');
      }
      if (ROLE_RANK[profile.role] < ROLE_RANK[minRole]) {
        throw new ForbiddenException('Brak uprawnień do tej operacji');
      }
      return true;
    }

    const exactRoles = this.reflector.getAllAndOverride<ProfileRole[]>(
      ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!exactRoles || exactRoles.length === 0) {
      return true;
    }

    if (!profile) {
      throw new ForbiddenException('Brak profilu użytkownika');
    }
    if (!exactRoles.includes(profile.role)) {
      throw new ForbiddenException('Brak uprawnień do tej operacji');
    }
    return true;
  }
}
