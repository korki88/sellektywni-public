import {
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  UnauthorizedException,
  UseGuards,
} from '@nestjs/common';
import { AiProposalStatus, ProfileRole } from '@prisma/client';
import type { Request } from 'express';
import {
  AuditAction,
  AuditManual,
  AuditResourceParam,
  AuditResourceType,
} from '../audit/audit-log.decorator';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { FinancialIntelligenceService } from './financial-intelligence.service';

@UseGuards(RolesGuard)
@Roles(ProfileRole.STAFF, ProfileRole.OWNER)
@MinimumRole(ProfileRole.OWNER)
@Controller('staff/financial-intelligence')
export class FinancialIntelligenceController {
  constructor(private readonly financial: FinancialIntelligenceService) {}

  @Post('analyze')
  @AuditAction('FINANCIAL_INTELLIGENCE_ANALYZE')
  analyze() {
    return this.financial.analyzeCashflowRisk();
  }

  @Get('proposals')
  @AuditAction('FINANCIAL_INTELLIGENCE_LIST_PROPOSALS')
  list(@Query('status') status?: string) {
    const allowed = Object.values(AiProposalStatus) as string[];
    const normalized = status?.trim().toUpperCase();
    const parsed =
      normalized && allowed.includes(normalized)
        ? (normalized as AiProposalStatus)
        : undefined;
    return this.financial.listProposals(parsed);
  }

  @Post('proposals/:id/accept-and-launch-marketing')
  @AuditManual()
  @AuditAction('FINANCIAL_INTELLIGENCE_ACCEPT_AND_LAUNCH_MARKETING')
  @AuditResourceType('AI_PROPOSAL')
  @AuditResourceParam('id')
  acceptAndLaunch(@Param('id') proposalId: string, @Req() req: Request) {
    const ownerUserId = req.profile?.userId;
    if (!ownerUserId) {
      throw new UnauthorizedException('Brak profilu użytkownika');
    }
    return this.financial.acceptAndLaunchMarketing(proposalId, {
      userId: ownerUserId,
      userEmail: req.profile?.email ?? req.supabaseJwt?.email ?? null,
      ipAddress: this.resolveIpAddress(req),
    });
  }

  @Post('proposals/:id/reject')
  @AuditManual()
  @AuditAction('FINANCIAL_INTELLIGENCE_REJECT_PROPOSAL')
  @AuditResourceType('AI_PROPOSAL')
  @AuditResourceParam('id')
  rejectProposal(@Param('id') proposalId: string, @Req() req: Request) {
    const ownerUserId = req.profile?.userId;
    if (!ownerUserId) {
      throw new UnauthorizedException('Brak profilu użytkownika');
    }
    return this.financial.rejectProposal(proposalId, {
      userId: ownerUserId,
      userEmail: req.profile?.email ?? req.supabaseJwt?.email ?? null,
      ipAddress: this.resolveIpAddress(req),
    });
  }

  private resolveIpAddress(req: Request): string | null {
    const forwarded = req.headers['x-forwarded-for'];
    if (typeof forwarded === 'string' && forwarded.trim().length > 0) {
      return forwarded.split(',')[0]?.trim() || null;
    }
    if (Array.isArray(forwarded) && forwarded.length > 0) {
      const first = forwarded[0]?.trim();
      if (first) return first;
    }
    const remoteIp = req.ip?.trim();
    return remoteIp && remoteIp.length > 0 ? remoteIp : null;
  }
}
