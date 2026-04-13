import { Controller, Get } from '@nestjs/common';
import { MarketService } from './market/market.service';

/** Publiczna konfiguracja rynku dla klientów (Flutter / WWW) — bez JWT. */
@Controller('config')
export class ShopConfigController {
  constructor(private readonly shopMarket: MarketService) {}

  @Get('market')
  getMarket() {
    return {
      marketId: this.shopMarket.marketId(),
      primaryCountry: this.shopMarket.primaryCountryCode(),
      currency: this.shopMarket.primaryCurrency(),
      locale: this.shopMarket.primaryLocale(),
      supportedCountries: this.shopMarket.supportedCountries(),
    };
  }
}
