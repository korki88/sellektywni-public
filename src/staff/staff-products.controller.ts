import { Controller, Get, Param, Patch } from '@nestjs/common';
import { StaffProductsService } from './staff-products.service';

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
