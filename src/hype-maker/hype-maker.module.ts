import { Module } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module';
import { NotificationModule } from '../notifications/notification.module';
import { PrismaModule } from '../prisma/prisma.module';
import { SocialMediaIntegratorModule } from '../social-media-integrator/social-media-integrator.module';
import { HypeMakerService } from './hype-maker.service';

@Module({
  imports: [
    PrismaModule,
    AuditModule,
    NotificationModule,
    SocialMediaIntegratorModule,
  ],
  providers: [HypeMakerService],
  exports: [HypeMakerService],
})
export class HypeMakerModule {}
