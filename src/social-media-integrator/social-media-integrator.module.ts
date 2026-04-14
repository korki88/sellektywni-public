import { Module } from '@nestjs/common';
import { AuditModule } from '../audit/audit.module';
import { PrismaModule } from '../prisma/prisma.module';
import { SocialMediaService } from './social-media-integrator.service';

@Module({
  imports: [PrismaModule, AuditModule],
  providers: [SocialMediaService],
  exports: [SocialMediaService],
})
export class SocialMediaIntegratorModule {}
