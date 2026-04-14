import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { APP_INTERCEPTOR } from '@nestjs/core';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { CmsModule } from './cms/cms.module';
import { CoreModule } from './core/core.module';
import { ExperimentsController } from './experiments/experiments.controller';
import { ExperimentsModule } from './experiments/experiments.module';
import { MailModule } from './mail/mail.module';
import { ScheduledTasksModule } from './notifications/scheduled.module';
import { AdminController } from './admin/admin.controller';
import { AdminFinanceController } from './admin/admin-finance.controller';
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
import { StaffCmsController } from './staff/staff-cms.controller';
import { StaffReturnsController } from './staff/staff-returns.controller';
import { StaffSupportController } from './staff/staff-support.controller';
import { StaffExperimentsController } from './staff/staff-experiments.controller';
import { StaffGiftCardsController } from './staff/staff-gift-cards.controller';
import { StaffReviewsController } from './staff/staff-reviews.controller';
import { StaffAuditController } from './staff/staff-audit.controller';
import { SupportController } from './support/support.controller';
import { SupportModule } from './support/support.module';
import { StaffAuditInterceptor } from './audit/staff-audit.interceptor';
import { AuditModule } from './audit/audit.module';
import { FinancialIntelligenceModule } from './financial-intelligence/financial-intelligence.module';
import { FinancialIntelligenceController } from './financial-intelligence/financial-intelligence.controller';
import { MarketingAutomationModule } from './marketing-automation/marketing-automation.module';
import { MarketingAutomationController } from './marketing-automation/marketing-automation.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ScheduleModule.forRoot(),
    MailModule,
    CoreModule,
    PrismaModule,
    ProfilesModule,
    AuthModule,
    AdminModule,
    StaffModule,
    OrderModule,
    ShippingModule,
    CmsModule,
    SupportModule,
    AuditModule,
    FinancialIntelligenceModule,
    MarketingAutomationModule,
    ExperimentsModule,
    ScheduledTasksModule,
  ],
  providers: [
    SupabaseJwtMiddleware,
    LoadProfileMiddleware,
    {
      provide: APP_INTERCEPTOR,
      useClass: StaffAuditInterceptor,
    },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer
      .apply(SupabaseJwtMiddleware, LoadProfileMiddleware)
      .forRoutes(AdminController, AdminFinanceController);

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
        StaffReturnsController,
        StaffCmsController,
        StaffSupportController,
        StaffExperimentsController,
        StaffGiftCardsController,
        StaffReviewsController,
        StaffAuditController,
        FinancialIntelligenceController,
        MarketingAutomationController,
        DotykackaDevController,
        OrderController,
        ShippingController,
      );

    consumer
      .apply(SupabaseJwtMiddleware)
      .forRoutes(AuthController, ExperimentsController);

    consumer
      .apply(SupabaseJwtMiddleware, LoadProfileMiddleware)
      .forRoutes(SupportController);
  }
}
