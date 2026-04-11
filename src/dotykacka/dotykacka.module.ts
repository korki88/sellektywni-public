import { HttpModule } from '@nestjs/axios';
import { Module } from '@nestjs/common';
import { DotykackaService } from './dotykacka.service';

@Module({
  imports: [HttpModule],
  providers: [DotykackaService],
  exports: [DotykackaService],
})
export class DotykackaModule {}
