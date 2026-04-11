import { Controller, Get } from '@nestjs/common';

@Controller('staff')
export class StaffController {
  @Get('ping')
  ping() {
    return { ok: true, scope: 'staff' };
  }
}
