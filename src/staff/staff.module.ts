import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { StaffController } from './staff.controller';
import { StaffCustomersController } from './staff-customers.controller';
import { StaffCustomersService } from './staff-customers.service';
import { StaffProductsController } from './staff-products.controller';
import { StaffProductsService } from './staff-products.service';

@Module({
  imports: [AuthModule],
  controllers: [
    StaffController,
    StaffProductsController,
    StaffCustomersController,
  ],
  providers: [StaffProductsService, StaffCustomersService],
})
export class StaffModule {}
