import { Controller, Get, Param, Patch, UseGuards } from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { StaffProductsService } from './staff-products.service';

@UseGuards(RolesGuard)
@MinimumRole(ProfileRole.STAFF)
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
