import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import type { Request } from 'express';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { PatchFinancialGoalDto } from './dto/patch-financial-goal.dto';
import { UpsertFinancialGoalDto } from './dto/upsert-financial-goal.dto';
import { ProfitAnalysisService } from '../financial-intelligence/profit-analysis.service';

@UseGuards(RolesGuard)
@MinimumRole(ProfileRole.OWNER)
@Controller('admin/finance')
export class AdminFinanceController {
  constructor(private readonly profitAnalysis: ProfitAnalysisService) {}

  @Get('summary')
  summary(@Req() req: Request) {
    const actor = this.auditActor(req);
    return this.profitAnalysis.summary(actor);
  }

  @Get('goals')
  listGoals() {
    return this.profitAnalysis.listGoals();
  }

  @Post('goals')
  createGoal(@Body() dto: UpsertFinancialGoalDto) {
    return this.profitAnalysis.createGoal(dto);
  }

  @Patch('goals/:goalId')
  patchGoal(
    @Param('goalId') goalId: string,
    @Body() dto: PatchFinancialGoalDto,
  ) {
    return this.profitAnalysis.updateGoal(goalId, dto);
  }

  private auditActor(req: Request): {
    userId: string;
    userEmail?: string | null;
    ipAddress?: string | null;
  } {
    const userId = req.profile?.userId;
    if (!userId) {
      throw new UnauthorizedException('Brak profilu użytkownika');
    }
    const forwarded = req.headers['x-forwarded-for'];
    const ipAddress =
      typeof forwarded === 'string' && forwarded.trim().length > 0
        ? (forwarded.split(',')[0]?.trim() ?? null)
        : Array.isArray(forwarded) && forwarded.length > 0
          ? (forwarded[0]?.trim() ?? null)
          : (req.ip?.trim() ?? null);
    return {
      userId,
      userEmail: req.profile?.email ?? req.supabaseJwt?.email ?? null,
      ipAddress,
    };
  }
}
