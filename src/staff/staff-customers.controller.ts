import { Body, Controller, Get, Param, Patch } from '@nestjs/common';
import { StaffCustomersService } from './staff-customers.service';
import { UpdateStaffCustomerDto } from './dto/update-staff-customer.dto';

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
