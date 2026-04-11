import { ProfileRole } from '@prisma/client';

/**
 * Stałe UUID i e-maile dla trybu AUTH_DEV_MOCK (bez Supabase).
 * Muszą być zsynchronizowane z prisma/seed.js.
 * Dostępne loginy/hasła w kliencie: mobile/lib/config/dev_mock_accounts.dart
 */
export const DEV_MOCK_PROFILES: Record<
  ProfileRole,
  { userId: string; email: string }
> = {
  [ProfileRole.OWNER]: {
    userId: '00000000-0000-4000-8000-000000000001',
    email: 'admin@dev.local',
  },
  [ProfileRole.STAFF]: {
    userId: '00000000-0000-4000-8000-000000000002',
    email: 'user@dev.local',
  },
  [ProfileRole.CUSTOMER]: {
    userId: '00000000-0000-4000-8000-000000000003',
    email: 'client@dev.local',
  },
};

/** Prefiks Bearer: dev-mock:OWNER | dev-mock:STAFF | dev-mock:CUSTOMER */
export const DEV_MOCK_BEARER_PREFIX = 'dev-mock:';
