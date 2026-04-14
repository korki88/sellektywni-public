import { Module } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module';
import { PrismaModule } from '../prisma/prisma.module';
import { MarketingAutomationModule } from '../marketing-automation/marketing-automation.module';
import { FinancialIntelligenceController } from './financial-intelligence.controller';
import { FinancialIntelligenceService } from './financial-intelligence.service';

@Module({
  imports: [PrismaModule, MarketingAutomationModule, AuditModule],
  controllers: [FinancialIntelligenceController],
  providers: [FinancialIntelligenceService],
  exports: [FinancialIntelligenceService],
})
export class FinancialIntelligenceModule {}
