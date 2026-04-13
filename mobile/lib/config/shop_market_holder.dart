import 'dart:convert';

import 'package:http/http.dart' as http;

import 'market_config.dart';

/// Wartości z backendu `GET /config/market` (nadpisują domyślne z [MarketConfig]).
class ShopMarketHolder {
  ShopMarketHolder._();

  static String _country = MarketConfig.defaultCountryCode;
  static String _currency = MarketConfig.defaultCurrencyCode;
  static String _locale = MarketConfig.defaultLocale;
  static String _marketId = MarketConfig.marketId;
  static List<String> _supported = [MarketConfig.defaultCountryCode];
  static List<Map<String, dynamic>> _displayCurrencies = const [];

  static String get marketId => _marketId;
  static String get countryCode => _country;
  static String get currencyCode => _currency;
  static String get locale => _locale;
  static List<String> get supportedCountries => List.unmodifiable(_supported);

  /// Waluty pomocnicze z API (np. EUR z kursem do PLN).
  static List<Map<String, dynamic>> get displayCurrencies =>
      List.unmodifiable(_displayCurrencies);

  /// Szacunkowa kwota w walucie obcej (np. dla EUR: amountPln / rate).
  static String? formatSecondary(num amountPln, String currencyCode, double rateToPrimary) {
    if (rateToPrimary <= 0) return null;
    final v = amountPln / rateToPrimary;
    return '${v.toStringAsFixed(2)} $currencyCode';
  }

  static Future<void> refresh(String apiBase) async {
    final base = apiBase.endsWith('/') ? apiBase.substring(0, apiBase.length - 1) : apiBase;
    try {
      final r = await http.get(Uri.parse('$base/config/market'));
      if (r.statusCode != 200) return;
      final j = jsonDecode(r.body);
      if (j is! Map<String, dynamic>) return;
      _marketId = j['marketId']?.toString() ?? _marketId;
      _country = j['primaryCountry']?.toString().toUpperCase() ?? _country;
      _currency = j['currency']?.toString().toUpperCase() ?? _currency;
      _locale = j['locale']?.toString() ?? _locale;
      final list = j['supportedCountries'];
      if (list is List && list.isNotEmpty) {
        _supported = list.map((e) => e.toString().toUpperCase()).where((s) => s.length == 2).toList();
      }
      final dc = j['displayCurrencies'];
      if (dc is List) {
        _displayCurrencies = dc.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {
      /* sieć / CORS — zostają domyślne PL */
    }
  }

  static String formatMoney(num? amount) {
    final v = amount ?? 0;
    final c = _currency;
    if (c == 'PLN') {
      return '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2)} zł';
    }
    return '${v.toStringAsFixed(2)} $c';
  }
}
