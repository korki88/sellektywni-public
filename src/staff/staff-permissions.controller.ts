import { Body, Controller, Get, Param, Patch, UseGuards } from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { UpdateStaffPermissionsDto } from './dto/update-staff-permissions.dto';
import { StaffPermissionsService } from './staff-permissions.service';

@UseGuards(RolesGuard)
@MinimumRole(ProfileRole.OWNER)
@Controller('staff/permissions')
export class StaffPermissionsController {
  constructor(private readonly permissions: StaffPermissionsService) {}

  @Get('users')
  listUsers() {
    return this.permissions.listUsers();
  }

  @Patch(':userId')
  update(
    @Param('userId') userId: string,
    @Body() dto: UpdateStaffPermissionsDto,
  ) {
    return this.permissions.updatePermissions(userId, dto.permissions);
  }
}
