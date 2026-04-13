import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { CoreModule } from './core/core.module';
import { AdminController } from './admin/admin.controller';
import { AdminModule } from './admin/admin.module';
import { AuthController } from './auth/auth.controller';
import { AuthModule } from './auth/auth.module';
import { LoadProfileMiddleware } from './auth/middleware/load-profile.middleware';
import { SupabaseJwtMiddleware } from './auth/middleware/supabase-jwt.middleware';
import { DotykackaDevController } from './dotykacka/dotykacka-dev.controller';
import { OrderModule } from './order/order.module';
import { OrderController } from './order/order.controller';
import { PrismaModule } from './prisma/prisma.module';
import { ProfilesModule } from './profiles/profiles.module';
import { ShippingController } from './shipping/shipping.controller';
import { ShippingModule } from './shipping/shipping.module';
import { StaffController } from './staff/staff.controller';
import { StaffCustomersController } from './staff/staff-customers.controller';
import { StaffOrdersController } from './staff/staff-orders.controller';
import { StaffPermissionsController } from './staff/staff-permissions.controller';
import { StaffModule } from './staff/staff.module';
import { StaffPromoController } from './staff/staff-promo.controller';
import { StaffProductsController } from './staff/staff-products.controller';
import { StaffAnalyticsController } from './staff/staff-analytics.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    CoreModule,
    PrismaModule,
    ProfilesModule,
    AuthModule,
    AdminModule,
    StaffModule,
    OrderModule,
    ShippingModule,
  ],
  providers: [SupabaseJwtMiddleware, LoadProfileMiddleware],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer
      .apply(SupabaseJwtMiddleware, LoadProfileMiddleware)
      .forRoutes(AdminController);

    consumer
      .apply(SupabaseJwtMiddleware, LoadProfileMiddleware)
      .forRoutes(
        StaffController,
        StaffProductsController,
        StaffCustomersController,
        StaffOrdersController,
        StaffPermissionsController,
        StaffPromoController,
        StaffAnalyticsController,
        DotykackaDevController,
        OrderController,
        ShippingController,
      );

    consumer.apply(SupabaseJwtMiddleware).forRoutes(AuthController);
  }
}
