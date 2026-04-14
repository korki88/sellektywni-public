import { Controller, Get, Query, Req, UseGuards } from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import type { Request } from 'express';
import { assertStaffPermission } from '../auth/assert-staff-permission';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { PermissionKeys } from '../auth/permissions';
import { AuditAction } from '../audit/audit-log.decorator';
import { StaffAuditService } from './staff-audit.service';

@UseGuards(RolesGuard)
@Roles(ProfileRole.STAFF, ProfileRole.OWNER)
@MinimumRole(ProfileRole.OWNER)
@Controller('staff/audit-logs')
export class StaffAuditController {
  constructor(private readonly audit: StaffAuditService) {}

  @Get()
  @AuditAction('AUDIT_LOGS_LIST')
  list(
    @Req() req: Request,
    @Query('offset') offsetRaw?: string,
    @Query('limit') limitRaw?: string,
    @Query('userId') userId?: string,
    @Query('userEmail') userEmail?: string,
    @Query('action') action?: string,
    @Query('resourceType') resourceType?: string,
  ) {
    assertStaffPermission(req, PermissionKeys.managePermissions);
    const offset = Number.isFinite(Number(offsetRaw))
      ? Math.max(0, Number(offsetRaw))
      : 0;
    const limit = Number.isFinite(Number(limitRaw))
      ? Math.min(200, Math.max(1, Number(limitRaw)))
      : 50;
    return this.audit.listLogs({
      offset,
      limit,
      userId: userId?.trim() || undefined,
      userEmail: userEmail?.trim() || undefined,
      action: action?.trim() || undefined,
      resourceType: resourceType?.trim() || undefined,
    });
  }
}
