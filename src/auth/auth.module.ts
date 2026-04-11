import { Module } from '@nestjs/common';
import { ProfilesModule } from '../profiles/profiles.module';
import { AuthController } from './auth.controller';
import { RolesGuard } from './guards/roles.guard';

@Module({
  imports: [ProfilesModule],
  controllers: [AuthController],
  providers: [RolesGuard],
  exports: [RolesGuard],
})
export class AuthModule {}
