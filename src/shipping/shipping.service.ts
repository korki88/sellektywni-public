import { Injectable } from '@nestjs/common';

type CarrierPoint = {
  id: string;
  name: string;
  address: string;
  postalCode: string;
  city: string;
  lat: number;
  lng: number;
};

@Injectable()
export class ShippingService {
  private readonly inpostPoints: CarrierPoint[] = [
    {
      id: 'WAW01A',
      name: 'InPost Paczkomat WAW01A',
      address: 'ul. Marszałkowska 10',
      postalCode: '00-001',
      city: 'Warszawa',
      lat: 52.2297,
      lng: 21.0122,
    },
    {
      id: 'KRK02B',
      name: 'InPost Paczkomat KRK02B',
      address: 'ul. Karmelicka 12',
      postalCode: '31-128',
      city: 'Kraków',
      lat: 50.0647,
      lng: 19.945,
    },
    {
      id: 'GDA03C',
      name: 'InPost Paczkomat GDA03C',
      address: 'ul. Długa 3',
      postalCode: '80-827',
      city: 'Gdańsk',
      lat: 54.352,
      lng: 18.6466,
    },
  ];

  listProviders() {
    return [
      {
        code: 'INPOST',
        name: 'InPost',
        supportsParcelLocker: true,
        supportsCourier: true,
        supportsMapPoints: true,
      },
      {
        code: 'DPD',
        name: 'DPD',
        supportsParcelLocker: false,
        supportsCourier: true,
        supportsMapPoints: true,
      },
      {
        code: 'DHL',
        name: 'DHL eCommerce',
        supportsParcelLocker: true,
        supportsCourier: true,
        supportsMapPoints: true,
      },
      {
        code: 'POCZTA_POLSKA',
        name: 'Poczta Polska',
        supportsParcelLocker: false,
        supportsCourier: true,
        supportsMapPoints: true,
      },
    ];
  }

  findInpostPoints(options?: {
    postalCode?: string;
    city?: string;
    lat?: number;
    lng?: number;
    limit?: number;
  }) {
    const limit = options?.limit ?? 12;
    let rows = [...this.inpostPoints];
    if (options?.postalCode) {
      const p = options.postalCode.slice(0, 2);
      rows = rows.filter((r) => r.postalCode.startsWith(p));
    } else if (options?.city) {
      const city = options.city.toLowerCase();
      rows = rows.filter((r) => r.city.toLowerCase().includes(city));
    }
    if (typeof options?.lat === 'number' && typeof options?.lng === 'number') {
      rows.sort((a, b) => {
        const da = (a.lat - options.lat!) ** 2 + (a.lng - options.lng!) ** 2;
        const db = (b.lat - options.lat!) ** 2 + (b.lng - options.lng!) ** 2;
        return da - db;
      });
    }
    return rows.slice(0, Math.max(1, limit));
  }

  estimatePrice(input: {
    providerCode: string;
    shipmentType: 'PARCEL_LOCKER' | 'COURIER';
    orderTotal: number;
    weightKg?: number;
  }) {
    const weight = Math.max(0.1, input.weightKg ?? 1);
    const base =
      input.shipmentType === 'PARCEL_LOCKER'
        ? 11.99
        : input.providerCode === 'POCZTA_POLSKA'
          ? 13.49
          : 15.99;
    const surcharge = weight > 5 ? 4.5 : weight > 2 ? 2.0 : 0;
    const freeShipping = input.orderTotal >= 350;
    return {
      providerCode: input.providerCode,
      shipmentType: input.shipmentType,
      currency: 'PLN',
      price: freeShipping ? 0 : Number((base + surcharge).toFixed(2)),
      freeShippingThreshold: 350,
      estimatedDays: input.shipmentType === 'PARCEL_LOCKER' ? '1-2' : '1-3',
      mode: 'dev-simulation',
    };
  }
}
