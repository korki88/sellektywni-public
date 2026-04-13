import {
  Controller,
  ForbiddenException,
  Get,
  Query,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import type { Request } from 'express';
import { PermissionKeys } from '../auth/permissions';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { StaffAnalyticsService } from './staff-analytics.service';

@UseGuards(RolesGuard)
@MinimumRole(ProfileRole.STAFF)
@Controller('staff/analytics')
export class StaffAnalyticsController {
  constructor(private readonly analytics: StaffAnalyticsService) {}

  private assertAnalyticsAccess(req: Request): void {
    const p = req.profile;
    if (!p) {
      throw new UnauthorizedException('Brak profilu');
    }
    if (p.role === ProfileRole.OWNER) {
      return;
    }
    if (p.permissions.includes(PermissionKeys.viewAnalytics)) {
      return;
    }
    throw new ForbiddenException('Brak uprawnień do analityki');
  }

  private assertOrdersAccess(req: Request): void {
    const p = req.profile;
    if (!p) {
      throw new UnauthorizedException('Brak profilu');
    }
    if (p.role === ProfileRole.OWNER) {
      return;
    }
    if (p.permissions.includes(PermissionKeys.manageOrders)) {
      return;
    }
    throw new ForbiddenException('Brak uprawnień do magazynu');
  }

  @Get('summary')
  summary(@Req() req: Request) {
    this.assertAnalyticsAccess(req);
    return this.analytics.getSummary();
  }

  @Get('low-stock')
  lowStock(@Req() req: Request, @Query('threshold') threshold?: string) {
    this.assertOrdersAccess(req);
    const n = threshold != null ? Number(threshold) : 3;
    return this.analytics.listLowStock(n);
  }
}
