import { SetMetadata } from '@nestjs/common';
import type { ProfileRole } from '@prisma/client';

/** Metadane dla [RolesGuard] — minimalny poziom roli (dziedziczenie w górę). */
export const MIN_ROLE_KEY = 'rbac_min_role';

/**
 * OWNER (2) ≥ STAFF (1) ≥ CUSTOMER (0).
 * Np. `@MinimumRole(STAFF)` dopuszcza STAFF i OWNER; `@MinimumRole(OWNER)` tylko OWNER.
 */
export const MinimumRole = (role: ProfileRole) =>
  SetMetadata(MIN_ROLE_KEY, role);
