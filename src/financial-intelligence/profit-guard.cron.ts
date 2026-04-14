import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { ProfitGuardAiService } from './profit-guard-ai.service';

@Injectable()
export class ProfitGuardCron {
  private readonly logger = new Logger(ProfitGuardCron.name);

  constructor(private readonly profitGuard: ProfitGuardAiService) {}

  @Cron('0 3 * * *', { timeZone: 'Europe/Warsaw' })
  async runDaily(): Promise<void> {
    try {
      const result = await this.profitGuard.generateProfitGuardProposals();
      this.logger.log(
        `Profit Guard cron done: scanned=${result.scanned}, generated=${result.generated}, updated=${result.updated}`,
      );
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(`Profit Guard cron failed: ${message}`);
    }
  }
}
