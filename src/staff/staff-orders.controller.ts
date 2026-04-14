import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { ProfileRole } from '@prisma/client';
import {
  AuditAction,
  AuditManual,
  AuditResourceParam,
  AuditResourceType,
} from '../audit/audit-log.decorator';
import { assertStaffPermission } from '../auth/assert-staff-permission';
import { PermissionKeys } from '../auth/permissions';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { AddOrderStaffNoteDto } from './dto/add-order-staff-note.dto';
import { UpdateStaffOrderPaymentStatusDto } from './dto/update-staff-order-payment-status.dto';
import { UpdateStaffOrderStatusDto } from './dto/update-staff-order-status.dto';
import { StaffOrdersService } from './staff-orders.service';

@UseGuards(RolesGuard)
@Roles(ProfileRole.STAFF, ProfileRole.OWNER)
@MinimumRole(ProfileRole.STAFF)
@Controller('staff/orders')
export class StaffOrdersController {
  constructor(private readonly orders: StaffOrdersService) {}

  @Get()
  list(@Query('status') status: string | undefined, @Req() req: Request) {
    assertStaffPermission(req, PermissionKeys.manageOrders);
    return this.orders.listOrders(status);
  }

  @Get(':id')
  detail(@Param('id') id: string, @Req() req: Request) {
    assertStaffPermission(req, PermissionKeys.manageOrders);
    return this.orders.getOrderDetail(id);
  }

  @Post(':id/notes')
  addNote(
    @Param('id') id: string,
    @Body() dto: AddOrderStaffNoteDto,
    @Req() req: Request,
  ) {
    assertStaffPermission(req, PermissionKeys.manageOrders);
    const uid = req.profile?.userId;
    if (!uid) {
      throw new UnauthorizedException('Brak profilu użytkownika');
    }
    return this.orders.addStaffNote(id, uid, dto.body);
  }

  @Patch(':id/status')
  @AuditManual()
  @AuditAction('CHANGE_ORDER_STATUS')
  @AuditResourceType('ORDER')
  @AuditResourceParam('id')
  updateStatus(
    @Param('id') id: string,
    @Body() dto: UpdateStaffOrderStatusDto,
    @Req() req: Request,
  ) {
    assertStaffPermission(req, PermissionKeys.manageOrders);
    const userId = req.profile?.userId;
    if (!userId) {
      throw new UnauthorizedException('Brak profilu użytkownika');
    }
    return this.orders.updateOrderStatus(id, dto.status, {
      userId,
      userEmail: req.profile?.email ?? req.supabaseJwt?.email ?? null,
      ipAddress: this.resolveIpAddress(req),
    });
  }

  @Patch(':id/payment-status')
  @AuditManual()
  @AuditAction('CHANGE_ORDER_PAYMENT_STATUS')
  @AuditResourceType('ORDER')
  @AuditResourceParam('id')
  updatePaymentStatus(
    @Param('id') id: string,
    @Body() dto: UpdateStaffOrderPaymentStatusDto,
    @Req() req: Request,
  ) {
    assertStaffPermission(req, PermissionKeys.manageOrders);
    const userId = req.profile?.userId;
    if (!userId) {
      throw new UnauthorizedException('Brak profilu użytkownika');
    }
    return this.orders.updatePaymentStatus(id, dto.paymentStatus, {
      userId,
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
