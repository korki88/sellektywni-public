import { Module } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module';
import { DotykackaModule } from '../dotykacka/dotykacka.module';
import { HypeMakerModule } from '../hype-maker/hype-maker.module';
import { NotificationModule } from '../notifications/notification.module';
import { PrismaModule } from '../prisma/prisma.module';
import { MarketingAutomationModule } from '../marketing-automation/marketing-automation.module';
import { FinancialIntelligenceController } from './financial-intelligence.controller';
import { FinancialIntelligenceService } from './financial-intelligence.service';
import { ProfitGuardCron } from './profit-guard.cron';
import { ProfitGuardAiService } from './profit-guard-ai.service';
import { ProfitAnalysisService } from './profit-analysis.service';

@Module({
  imports: [
    PrismaModule,
    MarketingAutomationModule,
    HypeMakerModule,
    AuditModule,
    DotykackaModule,
    NotificationModule,
  ],
  controllers: [FinancialIntelligenceController],
  providers: [
    FinancialIntelligenceService,
    ProfitAnalysisService,
    ProfitGuardAiService,
    ProfitGuardCron,
  ],
  exports: [
    FinancialIntelligenceService,
    ProfitAnalysisService,
    ProfitGuardAiService,
  ],
})
export class FinancialIntelligenceModule {}
