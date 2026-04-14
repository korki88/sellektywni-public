import { HttpModule } from '@nestjs/axios';
import { Module } from '@nestjs/common';
import { AdminNotificationService } from './admin-notification.service';

@Module({
  imports: [HttpModule],
  providers: [AdminNotificationService],
  exports: [AdminNotificationService],
})
export class NotificationModule {}
