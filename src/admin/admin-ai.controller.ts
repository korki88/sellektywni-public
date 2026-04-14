import { Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { AiProposalStatus, ProfileRole } from '@prisma/client';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { ProfitGuardAiService } from '../financial-intelligence/profit-guard-ai.service';

@UseGuards(RolesGuard)
@MinimumRole(ProfileRole.OWNER)
@Controller('admin/ai')
export class AdminAiController {
  constructor(private readonly profitGuard: ProfitGuardAiService) {}

  @Get('proposals')
  listProposals(@Query('status') status?: string) {
    const normalized = status?.trim().toUpperCase();
    const allowed = Object.values(AiProposalStatus) as string[];
    const parsed =
      normalized && allowed.includes(normalized)
        ? (normalized as AiProposalStatus)
        : undefined;
    return this.profitGuard.listProfitGuardProposals(parsed);
  }

  @Post('proposals/generate')
  generateProposals() {
    return this.profitGuard.generateProfitGuardProposals();
  }
}
