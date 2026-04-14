import { Module } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module';
import { DotykackaModule } from '../dotykacka/dotykacka.module';
import { PrismaModule } from '../prisma/prisma.module';
import { MarketingAutomationModule } from '../marketing-automation/marketing-automation.module';
import { FinancialIntelligenceController } from './financial-intelligence.controller';
import { FinancialIntelligenceService } from './financial-intelligence.service';
import { ProfitGuardAiService } from './profit-guard-ai.service';
import { ProfitAnalysisService } from './profit-analysis.service';

@Module({
  imports: [
    PrismaModule,
    MarketingAutomationModule,
    AuditModule,
    DotykackaModule,
  ],
  controllers: [FinancialIntelligenceController],
  providers: [
    FinancialIntelligenceService,
    ProfitAnalysisService,
    ProfitGuardAiService,
  ],
  exports: [
    FinancialIntelligenceService,
    ProfitAnalysisService,
    ProfitGuardAiService,
  ],
})
export class FinancialIntelligenceModule {}
