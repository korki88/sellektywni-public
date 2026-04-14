import { Controller, Get, Post, UseGuards } from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { ProfitGuardAiService } from '../financial-intelligence/profit-guard-ai.service';

@UseGuards(RolesGuard)
@MinimumRole(ProfileRole.OWNER)
@Controller('admin/ai')
export class AdminAiController {
  constructor(private readonly profitGuard: ProfitGuardAiService) {}

  @Get('proposals')
  listProposals() {
    return this.profitGuard.listProfitGuardProposals();
  }

  @Post('proposals/generate')
  generateProposals() {
    return this.profitGuard.generateProfitGuardProposals();
  }
}
