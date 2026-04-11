import { HttpService } from '@nestjs/axios';
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AxiosError } from 'axios';
import { catchError, firstValueFrom } from 'rxjs';

/**
 * Klient REST API Dotykačka v2.
 * Wzorzec URL: GET/PATCH https://api.dotykacka.cz/v2/clouds/:cloudId/products/:id
 * @see https://docs.api.dotykacka.cz/
 */
@Injectable()
export class DotykackaService {
  private readonly logger = new Logger(DotykackaService.name);

  constructor(
    private readonly http: HttpService,
    private readonly config: ConfigService,
  ) {}

  isConfigured(): boolean {
    const cloudId = this.config.get<string>('DOTYKACKA_CLOUD_ID');
    const token = this.config.get<string>('DOTYKACKA_ACCESS_TOKEN');
    return Boolean(cloudId?.trim() && token?.trim());
  }

  private baseUrl(): string {
    const base = this.config.get<string>('DOTYKACKA_BASE_URL', 'https://api.dotykacka.cz/v2').replace(/\/$/, '');
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
      this.logger.debug('Dotykačka: brak CLOUD_ID / ACCESS_TOKEN — pomijam weryfikację zdalną');
      return null;
    }
    const url = `${this.baseUrl()}/products/${encodeURIComponent(dotykackaProductId)}`;
    const { data } = await firstValueFrom(
      this.http.get<unknown>(url, { headers: this.authHeaders() }).pipe(
        catchError((err: AxiosError) => {
          this.logger.warn(`Dotykačka GET products/${dotykackaProductId}: ${err.message}`);
          throw err;
        }),
      ),
    );
    return data;
  }
}
