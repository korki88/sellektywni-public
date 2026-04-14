import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { CreatePromoDto } from './dto/create-promo.dto';
import { PatchPromoDto } from './dto/patch-promo.dto';
import { StaffPromoService } from './staff-promo.service';

@UseGuards(RolesGuard)
@MinimumRole(ProfileRole.STAFF)
@Controller('staff/promo-codes')
export class StaffPromoController {
  constructor(private readonly staffPromo: StaffPromoService) {}

  @Get()
  list() {
    return this.staffPromo.list();
  }

  @Post()
  create(@Body() dto: CreatePromoDto) {
    return this.staffPromo.create(dto);
  }

  @Patch(':id')
  patch(@Param('id') id: string, @Body() dto: PatchPromoDto) {
    return this.staffPromo.patch(id, dto);
  }
}
