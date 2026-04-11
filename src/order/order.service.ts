import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { ProductStatus } from '@prisma/client';
import { DotykackaService } from '../dotykacka/dotykacka.service';
import { AdminNotificationService } from '../notification/admin-notification.service';
import { ProductService } from '../product/product.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreateOrderDto } from './dto/create-order.dto';

@Injectable()
export class OrderService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly productService: ProductService,
    private readonly dotykacka: DotykackaService,
    private readonly adminNotification: AdminNotificationService,
  ) {}

  async placePendingOrder(dto: CreateOrderDto) {
    if (!dto.productId && !dto.idDotykacka) {
      throw new BadRequestException('Podaj productId lub idDotykacka');
    }

    const existing = await this.productService.findByIdOrDotykacka(dto.productId, dto.idDotykacka);
    if (!existing) {
      throw new NotFoundException('Produkt nie istnieje');
    }

    if (existing.status !== ProductStatus.AVAILABLE) {
      throw new ConflictException(`Produkt niedostępny (status: ${existing.status})`);
    }

    if (this.dotykacka.isConfigured()) {
      await this.dotykacka.getProduct(existing.idDotykacka);
    }

    const updated = await this.prisma.product.update({
      where: { id: existing.id },
      data: { status: ProductStatus.PENDING_APPROVAL },
    });

    await this.adminNotification.notifyOrderPendingApproval(updated);

    return {
      message: 'Zamówienie przyjęte do weryfikacji; produkt oznaczono jako PENDING_APPROVAL',
      product: updated,
    };
  }
}
