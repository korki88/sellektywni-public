import { SetMetadata } from '@nestjs/common';
import type { ProfileRole } from '@prisma/client';

export const ROLES_KEY = 'rbac_roles';

export const Roles = (...roles: ProfileRole[]) => SetMetadata(ROLES_KEY, roles);
