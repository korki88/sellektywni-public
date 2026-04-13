# Rynek, waluta, locale (PL jako start, rozszerzenie modułowe)

Sklep jest **najpierw dopasowany do Polski** (kraj **PL**, waluta **PLN**, język interfejsu **pl**). Architektura pozwala **dokładać kolejne kraje** bez przebudowy całości — przez konfigurację i osobne moduły integracji tam, gdzie prawo lub operator tego wymaga.

## Backend (NestJS)

| Zmienna | Domyślnie | Znaczenie |
|---------|-----------|-----------|
| `SHOP_MARKET_ID` | `PL` lub `SHOP_PRIMARY_COUNTRY` | Identyfikator rynku (np. przyszłe `EU-PL`). |
| `SHOP_PRIMARY_COUNTRY` | `PL` | Kod ISO 3166-1 alpha-2 — kraj „główny”. |
| `SHOP_PRIMARY_CURRENCY` | `PLN` | Waluta rozliczeń w API płatności / szacunków wysyłki. |
| `SHOP_PRIMARY_LOCALE` | `pl-PL` | Locale BCP 47 (klient Flutter może go pokazać w `/config/market`). |
| `SHOP_SUPPORTED_COUNTRIES` | *(puste)* | Opcjonalnie CSV, np. `PL,DE`. Gdy puste — **tylko** kraj primary. |

**Endpoint publiczny (bez JWT):** `GET /config/market` — zwraca `marketId`, `primaryCountry`, `currency`, `locale`, `supportedCountries`. Flutter ładuje to przy starcie (`ShopMarketHolder`).

**Walidacja adresu:** `OrderService` dopuszcza kraj tylko z listy `supportedCountries` (komunikat po polsku, gdy jedynym krajem jest PL).

**Płatności:** Przelewy24 w tym repozytorium jest **scenariuszem pod rynek polski**; przy rozszerzeniu na inny kraj zwykle potrzebny jest **osobny adapter** (inne konto merchant, waluta, endpointy).

**Wysyłka:** Cenniki „dev-simulation” są przykładowe pod PL; integracje kurierskie (InPost, ORLEN, itd.) należy **mapować per rynek** w osobnych modułach lub flagach.

## Flutter

- `mobile/lib/config/market_config.dart` — domyślne wartości z `--dart-define` (np. `SHOP_PRIMARY_COUNTRY`).
- `mobile/lib/config/shop_market_holder.dart` — nadpisanie danymi z `GET /config/market` po ustawieniu `API_BASE_URL`.

## Baza (Prisma)

- `AddressBookEntry.country` ma domyślnie `"PL"` — przy wielu krajach nadal poprawne jako domyślny kraj sklepu; rozszerzenie to głównie walidacja i UI.

## Kolejne kroki przy nowym kraju (skrót)

1. Ustawić `SHOP_SUPPORTED_COUNTRIES` i ewentualnie osobny moduł płatności / przewoźników.
2. Dodać tłumaczenia UI (obecnie polski — osobny pakiet i18n lub ARB).
3. Zweryfikować VAT / faktury / RODO — poza zakresem samego kodu sklepu.

Szczegóły sekretów i środowisk: [SECRETS.md](SECRETS.md).
