import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ProfileRole } from '@prisma/client';
import type { Request } from 'express';
import type { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';
import { AuditService } from './audit.service';
import { ROLES_KEY } from '../auth/decorators/roles.decorator';
import {
  AUDIT_ACTION_KEY,
  AUDIT_MANUAL_KEY,
  AUDIT_RESOURCE_PARAM_KEY,
  AUDIT_RESOURCE_TYPE_KEY,
} from './audit-log.decorator';

@Injectable()
export class StaffAuditInterceptor implements NestInterceptor {
  constructor(
    private readonly reflector: Reflector,
    private readonly audit: AuditService,
  ) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
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
    const manualLogged =
      this.reflector.getAllAndOverride<boolean>(AUDIT_MANUAL_KEY, [
        context.getHandler(),
        context.getClass(),
      ]) === true;
    if (manualLogged) {
      return next.handle();
    }

    const req = context.switchToHttp().getRequest<Request>();
    const userId = req.profile?.userId;
    if (!userId) {
      return next.handle();
    }
    const userEmail =
      req.profile?.email?.trim() ||
      req.supabaseJwt?.email?.trim() ||
      `user-${userId}@unknown.local`;

    const action =
      this.reflector.getAllAndOverride<string>(AUDIT_ACTION_KEY, [
        context.getHandler(),
        context.getClass(),
      ]) ?? this.defaultAction(req);
    const resourceType = this.resolveResourceType(req, context);
    const resourceId = this.resolveResourceId(req, context);

    return next.handle().pipe(
      tap({
        next: () => {
          void this.audit
            .logAction({
              userId,
              userEmail,
              action,
              resourceType,
              resourceId: resourceId ?? 'UNKNOWN',
              ipAddress: this.resolveIpAddress(req),
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

  private resolveResourceType(req: Request, context: ExecutionContext): string {
    const explicit =
      this.reflector.getAllAndOverride<string>(AUDIT_RESOURCE_TYPE_KEY, [
        context.getHandler(),
        context.getClass(),
      ]) ?? '';
    if (explicit.trim().length > 0) {
      return explicit.trim().toUpperCase();
    }
    const path = req.path.toLowerCase();
    if (path.includes('/staff/orders')) return 'ORDER';
    if (path.includes('/staff/products')) return 'PRODUCT';
    if (path.includes('/staff/customers')) return 'CUSTOMER';
    if (path.includes('/staff/returns')) return 'RETURN_REQUEST';
    if (path.includes('/staff/financial-intelligence/proposals'))
      return 'AI_PROPOSAL';
    if (path.includes('/staff/marketing')) return 'MARKETING';
    if (path.includes('/staff/permissions')) return 'PERMISSIONS';
    return 'UNKNOWN';
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

  private resolveIpAddress(req: Request): string | null {
    const forwarded = req.headers['x-forwarded-for'];
    if (typeof forwarded === 'string' && forwarded.trim().length > 0) {
      return forwarded.split(',')[0]?.trim() || null;
    }
    if (Array.isArray(forwarded) && forwarded.length > 0) {
      const first = forwarded[0]?.trim();
      if (first) return first;
    }
    const remoteIp = req.ip?.trim();
    return remoteIp && remoteIp.length > 0 ? remoteIp : null;
  }
}
