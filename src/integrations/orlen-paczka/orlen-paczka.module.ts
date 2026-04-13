import { Module } from '@nestjs/common';
import { OrlenPaczkaService } from './orlen-paczka.service';

@Module({
  providers: [OrlenPaczkaService],
  exports: [OrlenPaczkaService],
})
export class OrlenPaczkaModule {}
