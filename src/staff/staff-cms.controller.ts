import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import type { Request } from 'express';
import { assertStaffPermission } from '../auth/assert-staff-permission';
import { PermissionKeys } from '../auth/permissions';
import { CmsService } from '../cms/cms.service';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { UpsertCmsPageDto } from './dto/upsert-cms-page.dto';

@UseGuards(RolesGuard)
@MinimumRole(ProfileRole.STAFF)
@Controller('staff/cms')
export class StaffCmsController {
  constructor(private readonly cms: CmsService) {}

  @Get('pages')
  listAll(@Req() req: Request) {
    assertStaffPermission(req, PermissionKeys.manageCms);
    return this.cms.listAllForStaff();
  }

  @Post('pages')
  upsert(@Body() dto: UpsertCmsPageDto, @Req() req: Request) {
    assertStaffPermission(req, PermissionKeys.manageCms);
    return this.cms.upsertPage(dto);
  }
}
