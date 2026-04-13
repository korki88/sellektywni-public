import { HttpModule } from '@nestjs/axios';
import { Module } from '@nestjs/common';
import { DotykackaDevController } from './dotykacka-dev.controller';
import { DotykackaService } from './dotykacka.service';

@Module({
  imports: [HttpModule],
  controllers: [DotykackaDevController],
  providers: [DotykackaService],
  exports: [DotykackaService],
})
export class DotykackaModule {}
