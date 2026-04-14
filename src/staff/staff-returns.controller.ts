import { Body, Controller, Get, Param, Patch, UseGuards } from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { UpdateReturnRequestDto } from './dto/update-return-request.dto';
import { StaffReturnsService } from './staff-returns.service';

@UseGuards(RolesGuard)
@MinimumRole(ProfileRole.STAFF)
@Controller('staff/returns')
export class StaffReturnsController {
  constructor(private readonly returns: StaffReturnsService) {}

  @Get()
  list() {
    return this.returns.listReturns();
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateReturnRequestDto) {
    return this.returns.updateReturn(id, dto);
  }
}
