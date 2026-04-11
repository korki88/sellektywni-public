import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AdminController } from './admin/admin.controller';
import { AdminModule } from './admin/admin.module';
import { AuthController } from './auth/auth.controller';
import { AuthModule } from './auth/auth.module';
import { LoadProfileMiddleware } from './auth/middleware/load-profile.middleware';
import { SupabaseJwtMiddleware } from './auth/middleware/supabase-jwt.middleware';
import { OrderModule } from './order/order.module';
import { PrismaModule } from './prisma/prisma.module';
import { ProfilesModule } from './profiles/profiles.module';
import { StaffController } from './staff/staff.controller';
import { StaffCustomersController } from './staff/staff-customers.controller';
import { StaffModule } from './staff/staff.module';
import { StaffProductsController } from './staff/staff-products.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    PrismaModule,
    ProfilesModule,
    AuthModule,
    AdminModule,
    StaffModule,
    OrderModule,
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
      .forRoutes(StaffController, StaffProductsController, StaffCustomersController);

    consumer.apply(SupabaseJwtMiddleware).forRoutes(AuthController);
  }
}
