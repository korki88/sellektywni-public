import { Body, Controller, Post } from '@nestjs/common';
import { CreateOrderDto } from './dto/create-order.dto';
import { OrderService } from './order.service';

@Controller('order')
export class OrderController {
  constructor(private readonly orderService: OrderService) {}

  @Post()
  placeOrder(@Body() dto: CreateOrderDto) {
    return this.orderService.placePendingOrder(dto);
  }
}
