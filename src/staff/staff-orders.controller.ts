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
import { assertStaffPermission } from '../auth/assert-staff-permission';
import { PermissionKeys } from '../auth/permissions';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { AddOrderStaffNoteDto } from './dto/add-order-staff-note.dto';
import { UpdateStaffOrderPaymentStatusDto } from './dto/update-staff-order-payment-status.dto';
import { UpdateStaffOrderStatusDto } from './dto/update-staff-order-status.dto';
import { StaffOrdersService } from './staff-orders.service';

@UseGuards(RolesGuard)
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
  updateStatus(
    @Param('id') id: string,
    @Body() dto: UpdateStaffOrderStatusDto,
    @Req() req: Request,
  ) {
    assertStaffPermission(req, PermissionKeys.manageOrders);
    return this.orders.updateOrderStatus(id, dto.status);
  }

  @Patch(':id/payment-status')
  updatePaymentStatus(
    @Param('id') id: string,
    @Body() dto: UpdateStaffOrderPaymentStatusDto,
    @Req() req: Request,
  ) {
    assertStaffPermission(req, PermissionKeys.manageOrders);
    return this.orders.updatePaymentStatus(id, dto.paymentStatus);
  }
}
