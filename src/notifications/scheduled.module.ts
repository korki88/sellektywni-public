import { Module } from '@nestjs/common';
import { MailModule } from '../mail/mail.module';
import { AbandonedCartJob } from './abandoned-cart.job';

@Module({
  imports: [MailModule],
  providers: [AbandonedCartJob],
})
export class ScheduledTasksModule {}
