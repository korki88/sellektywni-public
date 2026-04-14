import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import type { Request } from 'express';
import { PermissionKeys } from '../auth/permissions';
import { assertStaffPermission } from '../auth/assert-staff-permission';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { CreateGiftCardDto } from './dto/create-gift-card.dto';
import { SetGiftCardActiveDto } from './dto/set-gift-card-active.dto';
import { StaffGiftCardsService } from './staff-gift-cards.service';

@UseGuards(RolesGuard)
@MinimumRole(ProfileRole.STAFF)
@Controller('staff/gift-cards')
export class StaffGiftCardsController {
  constructor(private readonly giftCards: StaffGiftCardsService) {}

  @Get()
  list(@Req() req: Request) {
    assertStaffPermission(req, PermissionKeys.manageGiftCards);
    return this.giftCards.list();
  }

  @Post()
  create(@Body() dto: CreateGiftCardDto, @Req() req: Request) {
    assertStaffPermission(req, PermissionKeys.manageGiftCards);
    let expiresAt: Date | null | undefined;
    if (dto.expiresAtIso != null && dto.expiresAtIso.trim() !== '') {
      const d = new Date(dto.expiresAtIso);
      if (Number.isNaN(d.getTime())) {
        throw new BadRequestException('Nieprawidłowa data ważności');
      }
      expiresAt = d;
    }
    return this.giftCards.create({
      code: dto.code,
      initialAmount: dto.initialAmount,
      currency: dto.currency,
      expiresAt,
      active: dto.active,
    });
  }

  @Patch(':id/active')
  setActive(
    @Param('id') id: string,
    @Body() body: SetGiftCardActiveDto,
    @Req() req: Request,
  ) {
    assertStaffPermission(req, PermissionKeys.manageGiftCards);
    return this.giftCards.setActive(id, body.active);
  }
}
