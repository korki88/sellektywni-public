import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ProfileRole } from '@prisma/client';
import type { Request } from 'express';
import { tap } from 'rxjs/operators';
import { PrismaService } from '../prisma/prisma.service';
import { ROLES_KEY } from '../auth/decorators/roles.decorator';
import {
  AUDIT_ACTION_KEY,
  AUDIT_RESOURCE_PARAM_KEY,
} from './audit-log.decorator';

@Injectable()
export class StaffAuditInterceptor implements NestInterceptor {
  constructor(
    private readonly reflector: Reflector,
    private readonly prisma: PrismaService,
  ) {}

  intercept(context: ExecutionContext, next: CallHandler) {
    if (context.getType<'http'>() !== 'http') {
      return next.handle();
    }

    const requiredRoles =
      this.reflector.getAllAndOverride<ProfileRole[]>(ROLES_KEY, [
        context.getHandler(),
        context.getClass(),
      ]) ?? [];
    const shouldAudit =
      requiredRoles.includes(ProfileRole.STAFF) ||
      requiredRoles.includes(ProfileRole.OWNER);
    if (!shouldAudit) {
      return next.handle();
    }

    const req = context.switchToHttp().getRequest<Request>();
    const userId = req.profile?.userId;
    if (!userId) {
      return next.handle();
    }

    const action =
      this.reflector.getAllAndOverride<string>(AUDIT_ACTION_KEY, [
        context.getHandler(),
        context.getClass(),
      ]) ?? this.defaultAction(req);
    const resourceId = this.resolveResourceId(req, context);

    return next.handle().pipe(
      tap({
        next: () => {
          void this.prisma.auditLog
            .create({
              data: {
                userId,
                action,
                resourceId: resourceId ?? undefined,
              },
            })
            .catch(() => {
              // Audyt nie może blokować requestu biznesowego.
            });
        },
      }),
    );
  }

  private defaultAction(req: Request): string {
    const route = req.route as { path?: string } | undefined;
    const routePath = route?.path ?? req.path;
    return `${req.method.toUpperCase()} ${routePath}`;
  }

  private resolveResourceId(
    req: Request,
    context: ExecutionContext,
  ): string | null {
    const explicitParam =
      this.reflector.getAllAndOverride<string>(AUDIT_RESOURCE_PARAM_KEY, [
        context.getHandler(),
        context.getClass(),
      ]) ?? '';
    if (explicitParam && typeof req.params?.[explicitParam] === 'string') {
      const value = req.params[explicitParam].trim();
      if (value) return value;
    }

    const paramCandidates = [
      'id',
      'userId',
      'orderId',
      'productId',
      'ticketId',
      'key',
    ];
    for (const key of paramCandidates) {
      const raw = req.params?.[key];
      if (typeof raw === 'string' && raw.trim().length > 0) {
        return raw.trim();
      }
    }

    const body = req.body as Record<string, unknown> | undefined;
    if (body) {
      const bodyCandidates = [
        'id',
        'userId',
        'orderId',
        'productId',
        'ticketId',
      ];
      for (const key of bodyCandidates) {
        const raw = body[key];
        if (typeof raw === 'string' && raw.trim().length > 0) {
          return raw.trim();
        }
      }
    }
    return null;
  }
}
