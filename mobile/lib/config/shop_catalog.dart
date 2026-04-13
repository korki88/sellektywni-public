/// Etykiety i stałe zgodne z API / Prisma (płatności, wysyłka, przewoźnicy).

String paymentMethodLabelPl(String? code) {
  switch (code) {
    case 'BLIK':
      return 'BLIK (Przelewy24)';
    case 'CARD_ONLINE':
      return 'Karta online (Przelewy24)';
    case 'BANK_TRANSFER':
      return 'Przelew tradycyjny';
    case 'CASH_ON_DELIVERY':
      return 'Płatność przy odbiorze (COD)';
    default:
      return code ?? '—';
  }
}

String paymentProviderLabelPl(String? code) {
  switch (code) {
    case 'PRZELEWY24':
      return 'Przelewy24';
    case 'BANK_TRANSFER_MOCK':
      return 'Przelew (symulacja dev)';
    case 'CASH_ON_DELIVERY':
      return 'COD';
    default:
      return code ?? '—';
  }
}

String paymentStatusLabelPl(String? code) {
  switch (code) {
    case 'PENDING':
      return 'Oczekuje';
    case 'PAID':
      return 'Opłacone';
    case 'FAILED':
      return 'Odrzucone / błąd';
    case 'CANCELED':
      return 'Anulowane';
    case 'COD_PENDING':
      return 'COD — do pobrania';
    default:
      return code ?? '—';
  }
}

String orderStatusLabelPl(String? code) {
  switch (code) {
    case 'PLACED':
      return 'Złożone';
    case 'PROCESSING':
      return 'W realizacji';
    case 'READY':
      return 'Gotowe do wydania / wysyłki';
    case 'COMPLETED':
      return 'Zakończone';
    case 'CANCELED':
      return 'Anulowane';
    default:
      return code ?? '—';
  }
}

String shippingMethodLabelPl(String? code) {
  switch (code) {
    case 'COURIER':
      return 'Kurier (DPD / DHL / InPost zależnie od wyboru klienta)';
    case 'PARCEL_LOCKER_INPOST':
      return 'Paczkomat InPost';
    case 'STORE_PICKUP':
      return 'Odbiór osobisty w salonie';
    default:
      return code ?? '—';
  }
}

bool expectsCourierOrLockerLabel(String? shippingMethod) {
  return shippingMethod == 'COURIER' || shippingMethod == 'PARCEL_LOCKER_INPOST';
}

const List<String> kSupportedPaymentMethodCodes = [
  'BLIK',
  'CARD_ONLINE',
  'BANK_TRANSFER',
  'CASH_ON_DELIVERY',
];

const List<Map<String, String>> kCourierIntegrationRows = [
  {'code': 'INPOST', 'name': 'InPost (ShipX API + fallback)'},
  {'code': 'ORLEN_PACZKA', 'name': 'ORLEN Paczka (SOAP)'},
  {'code': 'DPD', 'name': 'DPD Pickup'},
  {'code': 'DHL', 'name': 'DHL POP'},
  {'code': 'POCZTA_POLSKA', 'name': 'Poczta Polska'},
];
