import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Req,
  UseGuards,
} from '@nestjs/common';
import type { Request } from 'express';
import { ProfileRole } from '@prisma/client';
import { assertStaffPermission } from '../auth/assert-staff-permission';
import { PermissionKeys } from '../auth/permissions';
import { MinimumRole } from '../auth/decorators/minimum-role.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { UpdateReviewVisibilityDto } from './dto/update-review-visibility.dto';
import { StaffReviewsService } from './staff-reviews.service';

@UseGuards(RolesGuard)
@MinimumRole(ProfileRole.STAFF)
@Controller('staff/reviews')
export class StaffReviewsController {
  constructor(private readonly reviews: StaffReviewsService) {}

  @Get()
  list(@Req() req: Request) {
    assertStaffPermission(req, PermissionKeys.manageReviews);
    return this.reviews.listRecentPendingModeration();
  }

  @Patch(':reviewId')
  setVisible(
    @Param('reviewId') reviewId: string,
    @Body() dto: UpdateReviewVisibilityDto,
    @Req() req: Request,
  ) {
    assertStaffPermission(req, PermissionKeys.manageReviews);
    return this.reviews.setVisible(reviewId, dto.isVisible);
  }
}
