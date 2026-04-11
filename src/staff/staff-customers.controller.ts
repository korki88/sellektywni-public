import { Body, Controller, Get, Param, Patch, UseGuards } from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import { Roles } from '../auth/decorators/roles.decorator';
import { RolesGuard } from '../auth/guards/roles.guard';
import { StaffCustomersService } from './staff-customers.service';
import { UpdateStaffCustomerDto } from './dto/update-staff-customer.dto';

@UseGuards(RolesGuard)
@Roles(ProfileRole.STAFF)
@Controller('staff/customers')
export class StaffCustomersController {
  constructor(private readonly staffCustomers: StaffCustomersService) {}

  @Get(':userId')
  getProfile(@Param('userId') userId: string) {
    return this.staffCustomers.getProfile(userId);
  }

  @Patch(':userId')
  updateProfile(
    @Param('userId') userId: string,
    @Body() dto: UpdateStaffCustomerDto,
  ) {
    return this.staffCustomers.updateProfile(userId, dto);
  }
}
