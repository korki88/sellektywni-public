import { Controller, Get, UseGuards } from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';

@UseGuards(RolesGuard)
@MinimumRole(ProfileRole.STAFF)
@Controller('staff')
export class StaffController {
  @Get('ping')
  ping() {
    return { ok: true, scope: 'staff' };
  }
}
