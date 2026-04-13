import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import type { Request } from 'express';
import { PermissionKeys } from '../auth/permissions';
import { assertStaffPermission } from '../auth/assert-staff-permission';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { ExperimentsService } from '../experiments/experiments.service';
import { PatchExperimentActiveDto } from './dto/patch-experiment-active.dto';
import { UpsertExperimentDto } from './dto/upsert-experiment.dto';

@UseGuards(RolesGuard)
@MinimumRole(ProfileRole.STAFF)
@Controller('staff/experiments')
export class StaffExperimentsController {
  constructor(private readonly experiments: ExperimentsService) {}

  @Get()
  list(@Req() req: Request) {
    assertStaffPermission(req, PermissionKeys.manageExperiments);
    return this.experiments.listAllForStaff();
  }

  @Post()
  upsert(@Body() dto: UpsertExperimentDto, @Req() req: Request) {
    assertStaffPermission(req, PermissionKeys.manageExperiments);
    return this.experiments.upsertExperiment({
      key: dto.key,
      active: dto.active ?? true,
      variants: dto.variants ?? [],
    });
  }

  @Patch(':key/active')
  patchActive(
    @Param('key') key: string,
    @Body() dto: PatchExperimentActiveDto,
    @Req() req: Request,
  ) {
    assertStaffPermission(req, PermissionKeys.manageExperiments);
    return this.experiments.patchExperimentActive(
      decodeURIComponent(key),
      dto.active,
    );
  }
}
