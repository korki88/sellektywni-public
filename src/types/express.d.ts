import type { Profile } from '@prisma/client';

export type SupabaseJwtPayload = {
  sub: string;
  email?: string;
  app_metadata?: unknown;
};

declare global {
  namespace Express {
    interface Request {
      supabaseJwt?: SupabaseJwtPayload;
      profile?: Profile;
    }
  }
}

export {};
