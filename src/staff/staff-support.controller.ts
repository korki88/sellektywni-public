import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { ProfileRole } from '@prisma/client';
import { assertStaffPermission } from '../auth/assert-staff-permission';
import { PermissionKeys } from '../auth/permissions';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { AddSupportMessageDto } from '../support/dto/add-support-message.dto';
import { SupportService } from '../support/support.service';

@UseGuards(RolesGuard)
@MinimumRole(ProfileRole.STAFF)
@Controller('staff/support')
export class StaffSupportController {
  constructor(private readonly support: SupportService) {}

  @Get('tickets')
  list(@Req() req: Request) {
    assertStaffPermission(req, PermissionKeys.manageSupport);
    return this.support.listAllForStaff();
  }

  @Get('tickets/:ticketId')
  one(@Param('ticketId') ticketId: string, @Req() req: Request) {
    assertStaffPermission(req, PermissionKeys.manageSupport);
    return this.support.getTicketForStaff(ticketId);
  }

  @Post('tickets/:ticketId/messages')
  staffReply(
    @Param('ticketId') ticketId: string,
    @Body() dto: AddSupportMessageDto,
    @Req() req: Request,
  ) {
    assertStaffPermission(req, PermissionKeys.manageSupport);
    const uid = req.supabaseJwt?.sub;
    if (!uid) {
      throw new UnauthorizedException();
    }
    return this.support.addStaffMessage(ticketId, dto.body, uid);
  }
}
