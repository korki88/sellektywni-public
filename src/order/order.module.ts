import { Module } from '@nestjs/common';
import { PaymentsModule } from '../payments/payments.module';
import { DotykackaModule } from '../dotykacka/dotykacka.module';
import { NotificationModule } from '../notifications/notification.module';
import { ProductModule } from '../product/product.module';
import { PromoModule } from '../promo/promo.module';
import { ShippingModule } from '../shipping/shipping.module';
import { OrderController } from './order.controller';
import { InvoicePdfService } from './invoice-pdf.service';
import { OrderService } from './order.service';

@Module({
  imports: [
    ProductModule,
    PromoModule,
    DotykackaModule,
    NotificationModule,
    PaymentsModule,
    ShippingModule,
  ],
  controllers: [OrderController],
  providers: [OrderService, InvoicePdfService],
})
export class OrderModule {}
