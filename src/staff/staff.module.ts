import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { StaffController } from './staff.controller';
import { StaffCustomersController } from './staff-customers.controller';
import { StaffCustomersService } from './staff-customers.service';
import { StaffOrdersController } from './staff-orders.controller';
import { StaffOrdersService } from './staff-orders.service';
import { StaffPermissionsController } from './staff-permissions.controller';
import { StaffPermissionsService } from './staff-permissions.service';
import { StaffProductsController } from './staff-products.controller';
import { StaffProductsService } from './staff-products.service';
import { StaffPromoController } from './staff-promo.controller';
import { StaffPromoService } from './staff-promo.service';

@Module({
  imports: [AuthModule],
  controllers: [
    StaffController,
    StaffProductsController,
    StaffCustomersController,
    StaffOrdersController,
    StaffPermissionsController,
    StaffPromoController,
  ],
  providers: [
    StaffProductsService,
    StaffCustomersService,
    StaffOrdersService,
    StaffPermissionsService,
    StaffPromoService,
  ],
})
export class StaffModule {}
