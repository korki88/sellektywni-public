import { ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import type { Request } from 'express';

/** OWNER ma dostęp do wszystkich operacji panelu; STAFF — wg tablicy permissions. */
export function assertStaffPermission(
  req: Request,
  permissionKey: string,
): void {
  const p = req.profile;
  if (!p) {
    throw new UnauthorizedException('Brak profilu użytkownika');
  }
  if (p.role === ProfileRole.OWNER) {
    return;
  }
  if (p.permissions.includes(permissionKey)) {
    return;
  }
  throw new ForbiddenException('Brak uprawnień do tej operacji');
}
