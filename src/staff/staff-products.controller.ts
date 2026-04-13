import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { ProfileRole } from '@prisma/client';
import { assertStaffPermission } from '../auth/assert-staff-permission';
import { PermissionKeys } from '../auth/permissions';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { UpdateProductMerchandisingDto } from './dto/update-product-merchandising.dto';
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

  /** Polecane / podtytuł na karcie produktu (jak merchandising w Shopify). */
  @Patch(':id/merchandising')
  merchandising(
    @Param('id') id: string,
    @Body() dto: UpdateProductMerchandisingDto,
    @Req() req: Request,
  ) {
    assertStaffPermission(req, PermissionKeys.manageCatalog);
    return this.staffProducts.updateMerchandising(id, {
      isFeatured: dto.isFeatured,
      subtitle: dto.subtitle,
    });
  }
}
