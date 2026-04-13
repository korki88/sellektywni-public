import { Body, Controller, Get, Patch, UseGuards } from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { DotykackaService } from './dotykacka.service';

@UseGuards(RolesGuard)
@MinimumRole(ProfileRole.STAFF)
@Controller('dotykacka/dev')
export class DotykackaDevController {
  constructor(private readonly dotykacka: DotykackaService) {}

  @Get('stock')
  listStock() {
    return {
      enabled: this.dotykacka.isDevSimulationEnabled(),
      rows: this.dotykacka.listDevStock(),
    };
  }

  @Patch('stock')
  setStock(@Body() body: { idDotykacka?: string; stockQty?: number }) {
    const id = (body.idDotykacka ?? '').trim();
    const qty = Number(body.stockQty ?? 0);
    if (!id) {
      return { ok: false, message: 'Podaj idDotykacka' };
    }
    this.dotykacka.setDevStock(id, qty);
    return { ok: true, idDotykacka: id, stockQty: Math.max(0, Math.trunc(qty)) };
  }
}
