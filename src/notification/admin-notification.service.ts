import { HttpService } from '@nestjs/axios';
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Product } from '@prisma/client';
import { firstValueFrom } from 'rxjs';

export type ProductForNotification = Pick<Product, 'id' | 'idDotykacka' | 'name' | 'price' | 'status'>;

@Injectable()
export class AdminNotificationService {
  private readonly logger = new Logger(AdminNotificationService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly http: HttpService,
  ) {}

  async notifyOrderPendingApproval(product: ProductForNotification): Promise<void> {
    const payload = {
      type: 'ORDER_PENDING_APPROVAL',
      productId: product.id,
      idDotykacka: product.idDotykacka,
      name: product.name,
      price: product.price.toString(),
      status: product.status,
      at: new Date().toISOString(),
    };

    this.logger.log(`[ADMIN] Produkt oczekuje na akceptację zamówienia: ${JSON.stringify(payload)}`);

    const webhook = this.config.get<string>('ADMIN_WEBHOOK_URL')?.trim();
    if (webhook) {
      await firstValueFrom(this.http.post(webhook, payload));
    }
  }
}
