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
import { StaffAnalyticsController } from './staff-analytics.controller';
import { StaffAnalyticsService } from './staff-analytics.service';
import { StaffReturnsController } from './staff-returns.controller';
import { StaffReturnsService } from './staff-returns.service';
import { StaffReviewsController } from './staff-reviews.controller';
import { StaffReviewsService } from './staff-reviews.service';
import { StaffCmsController } from './staff-cms.controller';
import { StaffSupportController } from './staff-support.controller';
import { StaffExperimentsController } from './staff-experiments.controller';
import { StaffGiftCardsController } from './staff-gift-cards.controller';
import { StaffGiftCardsService } from './staff-gift-cards.service';
import { StaffAuditController } from './staff-audit.controller';
import { StaffAuditService } from './staff-audit.service';
import { CmsModule } from '../cms/cms.module';
import { SupportModule } from '../support/support.module';
import { ExperimentsModule } from '../experiments/experiments.module';
import { AuditModule } from '../audit/audit.module';

@Module({
  imports: [
    AuthModule,
    CmsModule,
    SupportModule,
    ExperimentsModule,
    AuditModule,
  ],
  controllers: [
    StaffController,
    StaffProductsController,
    StaffCustomersController,
    StaffOrdersController,
    StaffReturnsController,
    StaffCmsController,
    StaffSupportController,
    StaffExperimentsController,
    StaffGiftCardsController,
    StaffAuditController,
    StaffReviewsController,
    StaffPermissionsController,
    StaffPromoController,
    StaffAnalyticsController,
  ],
  providers: [
    StaffProductsService,
    StaffCustomersService,
    StaffOrdersService,
    StaffReturnsService,
    StaffPermissionsService,
    StaffPromoService,
    StaffAnalyticsService,
    StaffGiftCardsService,
    StaffAuditService,
    StaffReviewsService,
  ],
})
export class StaffModule {}
