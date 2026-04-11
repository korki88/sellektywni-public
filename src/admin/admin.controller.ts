import { Controller, Get, UseGuards } from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';

@UseGuards(RolesGuard)
@Roles(ProfileRole.OWNER)
@Controller('admin')
export class AdminController {
  @Get('ping')
  ping() {
    return { ok: true, scope: 'admin' };
  }
}
