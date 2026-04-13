import { Module } from '@nestjs/common';
import { PaymentsModule } from '../payments/payments.module';
import { DotykackaModule } from '../dotykacka/dotykacka.module';
import { NotificationModule } from '../notification/notification.module';
import { ProductModule } from '../product/product.module';
import { ShippingModule } from '../shipping/shipping.module';
import { OrderController } from './order.controller';
import { OrderService } from './order.service';

@Module({
  imports: [
    ProductModule,
    DotykackaModule,
    NotificationModule,
    PaymentsModule,
    ShippingModule,
  ],
  controllers: [OrderController],
  providers: [OrderService],
})
export class OrderModule {}
