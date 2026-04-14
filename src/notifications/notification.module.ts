import { HttpModule } from '@nestjs/axios';
import { Module } from '@nestjs/common';
import { AdminNotificationService } from './admin-notification.service';
import { FirebasePushService } from './firebase-push.service';

@Module({
  imports: [HttpModule],
  providers: [AdminNotificationService, FirebasePushService],
  exports: [AdminNotificationService, FirebasePushService],
})
export class NotificationModule {}
