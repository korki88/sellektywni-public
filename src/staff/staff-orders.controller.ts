import { Body, Controller, Get, Param, Patch, UseGuards } from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { UpdateStaffOrderPaymentStatusDto } from './dto/update-staff-order-payment-status.dto';
import { UpdateStaffOrderStatusDto } from './dto/update-staff-order-status.dto';
import { StaffOrdersService } from './staff-orders.service';

@UseGuards(RolesGuard)
@MinimumRole(ProfileRole.STAFF)
@Controller('staff/orders')
export class StaffOrdersController {
  constructor(private readonly orders: StaffOrdersService) {}

  @Get()
  list() {
    return this.orders.listOrders();
  }

  @Patch(':id/status')
  updateStatus(@Param('id') id: string, @Body() dto: UpdateStaffOrderStatusDto) {
    return this.orders.updateOrderStatus(id, dto.status);
  }

  @Patch(':id/payment-status')
  updatePaymentStatus(
    @Param('id') id: string,
    @Body() dto: UpdateStaffOrderPaymentStatusDto,
  ) {
    return this.orders.updatePaymentStatus(id, dto.paymentStatus);
  }
}
