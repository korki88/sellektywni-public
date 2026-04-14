/// Rynek sklepu — domyślnie Polska. Rozszerzenie: `--dart-define` lub `GET /config/market` ([ShopMarketHolder]).
class MarketConfig {
  MarketConfig._();

  static const String marketId = String.fromEnvironment(
    'SHOP_MARKET_ID',
    defaultValue: 'PL',
  );

  static const String defaultCountryCode = String.fromEnvironment(
    'SHOP_PRIMARY_COUNTRY',
    defaultValue: 'PL',
  );

  static const String defaultCurrencyCode = String.fromEnvironment(
    'SHOP_PRIMARY_CURRENCY',
    defaultValue: 'PLN',
  );

  static const String defaultLocale = String.fromEnvironment(
    'SHOP_PRIMARY_LOCALE',
    defaultValue: 'pl-PL',
  );
}
