import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { AdminController } from './admin.controller';
import { FinancialIntelligenceModule } from '../financial-intelligence/financial-intelligence.module';
import { AdminAiController } from './admin-ai.controller';
import { AdminFinanceController } from './admin-finance.controller';

@Module({
  imports: [AuthModule, FinancialIntelligenceModule],
  controllers: [AdminController, AdminFinanceController, AdminAiController],
})
export class AdminModule {}
