import { Controller, Get, UseGuards } from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';

@UseGuards(RolesGuard)
@MinimumRole(ProfileRole.OWNER)
@Controller('admin')
export class AdminController {
  @Get('ping')
  ping(): { ok: true; scope: 'admin' } {
    return { ok: true, scope: 'admin' };
  }
}
