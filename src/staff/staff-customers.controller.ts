import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import type { Request } from 'express';
import {
  AuditAction,
  AuditManual,
  AuditResourceParam,
  AuditResourceType,
} from '../audit/audit-log.decorator';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { StaffCustomersService } from './staff-customers.service';
import { UpdateStaffCustomerDto } from './dto/update-staff-customer.dto';

@UseGuards(RolesGuard)
@Roles(ProfileRole.STAFF, ProfileRole.OWNER)
@MinimumRole(ProfileRole.STAFF)
@Controller('staff/customers')
export class StaffCustomersController {
  constructor(private readonly staffCustomers: StaffCustomersService) {}

  @Get(':userId')
  getProfile(@Param('userId') userId: string) {
    return this.staffCustomers.getProfile(userId);
  }

  @Patch(':userId')
  @AuditManual()
  @AuditAction('UPDATE_CUSTOMER_PROFILE')
  @AuditResourceType('CUSTOMER')
  @AuditResourceParam('userId')
  updateProfile(
    @Param('userId') userId: string,
    @Body() dto: UpdateStaffCustomerDto,
    @Req() req: Request,
  ) {
    const actorUserId = req.profile?.userId;
    if (!actorUserId) {
      throw new UnauthorizedException('Brak profilu użytkownika');
    }
    return this.staffCustomers.updateProfile(userId, dto, {
      userId: actorUserId,
      userEmail: req.profile?.email ?? req.supabaseJwt?.email ?? null,
      ipAddress: this.resolveIpAddress(req),
    });
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
