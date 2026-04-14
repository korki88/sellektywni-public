import { Controller, Get, Req, UnauthorizedException } from '@nestjs/common';
import type { Request } from 'express';
import { ExperimentsService } from './experiments.service';

@Controller('experiments')
export class ExperimentsController {
  constructor(private readonly experiments: ExperimentsService) {}

  @Get('assignments')
  assignments(@Req() req: Request) {
    const uid = req.supabaseJwt?.sub;
    if (!uid) {
      throw new UnauthorizedException();
    }
    return this.experiments.getAssignments(uid);
  }
}
