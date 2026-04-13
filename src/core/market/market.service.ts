import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * Rynek sklepu: domyślnie Polska (PL / PLN / pl-PL).
 * Rozszerzenie o kolejne kraje: ustaw SHOP_SUPPORTED_COUNTRIES oraz ewentualnie osobne moduły płatności/wysyłki.
 */
@Injectable()
export class MarketService {
  constructor(private readonly config: ConfigService) {}

  /** Identyfikator rynku (np. „PL”, później „EU-PL”, „DACH”). */
  marketId(): string {
    return (
      this.config.get<string>('SHOP_MARKET_ID')?.trim().toUpperCase() ||
      this.primaryCountryCode()
    );
  }

  primaryCountryCode(): string {
    return (
      this.config.get<string>('SHOP_PRIMARY_COUNTRY')?.trim().toUpperCase() ||
      'PL'
    );
  }

  primaryCurrency(): string {
    return (
      this.config.get<string>('SHOP_PRIMARY_CURRENCY')?.trim().toUpperCase() ||
      'PLN'
    );
  }

  /** Locale BCP 47 — UI i formatowanie po stronie klienta. */
  primaryLocale(): string {
    return this.config.get<string>('SHOP_PRIMARY_LOCALE')?.trim() || 'pl-PL';
  }

  /** Kraje, do których dopuszczamy adres dostawy (ISO 3166-1 alpha-2). */
  supportedCountries(): string[] {
    const raw = this.config.get<string>('SHOP_SUPPORTED_COUNTRIES')?.trim();
    if (raw) {
      return [
        ...new Set(
          raw
            .split(',')
            .map((s) => s.trim().toUpperCase())
            .filter((s) => s.length === 2),
        ),
      ];
    }
    return [this.primaryCountryCode()];
  }

  isCountrySupported(countryCode: string): boolean {
    const c = countryCode.trim().toUpperCase();
    return this.supportedCountries().includes(c);
  }

  /**
   * Komunikat przy niedozwolonym kraju — domyślnie PL (jeden kraj).
   * Przy wielu krajach zwracana jest lista dozwolonych kodów.
   */
  unsupportedShippingCountryMessage(triedCountry: string): string {
    const list = this.supportedCountries();
    if (list.length === 1 && list[0] === 'PL') {
      return 'Obecnie obsługujemy wyłącznie wysyłkę na terenie Polski.';
    }
    return `Kraj „${triedCountry}” nie jest obsługiwany. Dozwolone: ${list.join(', ')}.`;
  }
}
