import { Controller, Get } from '@nestjs/common';

@Controller('admin')
export class AdminController {
  @Get('ping')
  ping() {
    return { ok: true, scope: 'admin' };
  }
}
