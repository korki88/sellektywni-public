import { Controller, Get, Param, Patch, UseGuards } from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { StaffProductsService } from './staff-products.service';

@UseGuards(RolesGuard)
@Roles(ProfileRole.STAFF)
@Controller('staff/products')
export class StaffProductsController {
  constructor(private readonly staffProducts: StaffProductsService) {}

  @Get('pending')
  pending() {
    return this.staffProducts.listPendingApproval();
  }

  @Patch(':id/accept')
  accept(@Param('id') id: string) {
    return this.staffProducts.acceptReservation(id);
  }

  @Patch(':id/reject')
  reject(@Param('id') id: string) {
    return this.staffProducts.rejectReservation(id);
  }
}
