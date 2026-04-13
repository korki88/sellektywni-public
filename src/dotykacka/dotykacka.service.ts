import { HttpService } from '@nestjs/axios';
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AxiosError } from 'axios';
import { catchError, firstValueFrom } from 'rxjs';
import { Product } from '@prisma/client';

/**
 * Klient REST API Dotykačka v2.
 * Wzorzec URL: GET/PATCH https://api.dotykacka.cz/v2/clouds/:cloudId/products/:id
 * @see https://docs.api.dotykacka.cz/
 */
@Injectable()
export class DotykackaService {
  private readonly logger = new Logger(DotykackaService.name);
  private readonly devStock = new Map<string, number>();

  constructor(
    private readonly http: HttpService,
    private readonly config: ConfigService,
  ) {}

  isConfigured(): boolean {
    const cloudId = this.config.get<string>('DOTYKACKA_CLOUD_ID');
    const token = this.config.get<string>('DOTYKACKA_ACCESS_TOKEN');
    return Boolean(cloudId?.trim() && token?.trim());
  }

  isDevSimulationEnabled(): boolean {
    const flag = this.config.get<string>('AUTH_DEV_MOCK');
    return flag?.toLowerCase() === 'true';
  }

  private baseUrl(): string {
    const base = this.config
      .get<string>('DOTYKACKA_BASE_URL', 'https://api.dotykacka.cz/v2')
      .replace(/\/$/, '');
    const cloudId = this.config.get<string>('DOTYKACKA_CLOUD_ID');
    return `${base}/clouds/${cloudId}`;
  }

  private authHeaders(): Record<string, string> {
    const token = this.config.get<string>('DOTYKACKA_ACCESS_TOKEN');
    return {
      Accept: 'application/json',
      Authorization: `Bearer ${token}`,
    };
  }

  /**
   * Pobiera produkt z chmury Dotykačka (encja `products`).
   */
  async getProduct(dotykackaProductId: string): Promise<unknown> {
    if (!this.isConfigured()) {
      this.logger.debug(
        'Dotykačka: brak CLOUD_ID / ACCESS_TOKEN — pomijam weryfikację zdalną',
      );
      return null;
    }
    const url = `${this.baseUrl()}/products/${encodeURIComponent(dotykackaProductId)}`;
    const { data } = await firstValueFrom(
      this.http.get<unknown>(url, { headers: this.authHeaders() }).pipe(
        catchError((err: AxiosError) => {
          this.logger.warn(
            `Dotykačka GET products/${dotykackaProductId}: ${err.message}`,
          );
          throw err;
        }),
      ),
    );
    return data;
  }

  async resolveStockQty(product: Product): Promise<number> {
    if (this.isDevSimulationEnabled() && this.devStock.has(product.idDotykacka)) {
      return this.devStock.get(product.idDotykacka) ?? product.stockQty;
    }
    if (!this.isConfigured()) {
      return product.stockQty;
    }
    try {
      const payload = await this.getProduct(product.idDotykacka);
      const remote = this.extractStockQty(payload);
      return remote ?? product.stockQty;
    } catch (e) {
      this.logger.warn(`Dotykačka stock fallback for ${product.idDotykacka}: ${e}`);
      return product.stockQty;
    }
  }

  setDevStock(dotykackaProductId: string, stockQty: number): void {
    this.devStock.set(dotykackaProductId, Math.max(0, stockQty));
  }

  listDevStock(): Array<{ idDotykacka: string; stockQty: number }> {
    return Array.from(this.devStock.entries()).map(([idDotykacka, stockQty]) => ({
      idDotykacka,
      stockQty,
    }));
  }

  private extractStockQty(payload: unknown): number | null {
    if (!payload || typeof payload !== 'object') return null;
    const data = payload as Record<string, unknown>;
    const candidates = [
      data['stock'],
      data['quantity'],
      data['amount'],
      data['availableQuantity'],
      data['amountInStock'],
    ];
    for (const raw of candidates) {
      if (typeof raw === 'number' && Number.isFinite(raw)) {
        return Math.max(0, Math.trunc(raw));
      }
      if (typeof raw === 'string') {
        const parsed = Number(raw);
        if (Number.isFinite(parsed)) {
          return Math.max(0, Math.trunc(parsed));
        }
      }
    }
    return null;
  }
}
