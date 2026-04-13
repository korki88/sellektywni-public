import { HttpService } from '@nestjs/axios';
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { catchError, firstValueFrom } from 'rxjs';

import { FeatureFlagsService } from '../core/feature-flags.service';
import { MarketService } from '../core/market/market.service';
import { OrlenPaczkaService } from '../integrations/orlen-paczka/orlen-paczka.service';
import { scalarToString } from '../lib/scalar-string';
import type { CarrierPoint } from './types/carrier-point';

@Injectable()
export class ShippingService {
  private readonly logger = new Logger(ShippingService.name);
  private readonly inpostFallbackPoints: CarrierPoint[] = [
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

  private providersCache: { expiresAt: number; data: unknown[] } | null = null;
  private inpostPointsCache = new Map<
    string,
    { expiresAt: number; data: CarrierPoint[] }
  >();
  /** DPD / DHL / Poczta — osobny cache (klucz z prefiksem przewoźnika). */
  private carrierPointsCache = new Map<
    string,
    { expiresAt: number; data: CarrierPoint[] }
  >();

  private readonly dpdFallbackPoints: CarrierPoint[] = [
    {
      id: 'DPD-PL-WAW1',
      name: 'DPD Pickup — Warszawa (przykład)',
      address: 'ul. Przykładowa 1',
      postalCode: '00-001',
      city: 'Warszawa',
      lat: 52.23,
      lng: 21.01,
    },
    {
      id: 'DPD-PL-KRK1',
      name: 'DPD Pickup — Kraków (przykład)',
      address: 'ul. Przykładowa 2',
      postalCode: '31-000',
      city: 'Kraków',
      lat: 50.06,
      lng: 19.94,
    },
  ];

  private readonly dhlFallbackPoints: CarrierPoint[] = [
    {
      id: 'DHL-PL-WAW1',
      name: 'DHL POP — Warszawa (przykład)',
      address: 'ul. Przykładowa 3',
      postalCode: '00-002',
      city: 'Warszawa',
      lat: 52.24,
      lng: 21.02,
    },
    {
      id: 'DHL-PL-GDA1',
      name: 'DHL POP — Gdańsk (przykład)',
      address: 'ul. Przykładowa 4',
      postalCode: '80-800',
      city: 'Gdańsk',
      lat: 54.35,
      lng: 18.65,
    },
  ];

  private readonly pocztaFallbackPoints: CarrierPoint[] = [
    {
      id: 'PP-WAW-001',
      name: 'Placówka Poczty Polskiej (przykład)',
      address: 'ul. Przykładowa 5',
      postalCode: '00-950',
      city: 'Warszawa',
      lat: 52.228,
      lng: 21.006,
    },
    {
      id: 'PP-KRK-002',
      name: 'Placówka Poczty Polskiej (przykład)',
      address: 'ul. Przykładowa 6',
      postalCode: '31-500',
      city: 'Kraków',
      lat: 50.061,
      lng: 19.937,
    },
  ];

  private readonly orlenFallbackPoints: CarrierPoint[] = [
    {
      id: 'OP-WAW-EX1',
      name: 'ORLEN Paczka — przykład (Warszawa)',
      address: 'ul. Marszałkowska 100',
      postalCode: '00-001',
      city: 'Warszawa',
      lat: 52.2297,
      lng: 21.0122,
    },
    {
      id: 'OP-KRK-EX1',
      name: 'ORLEN Paczka — przykład (Kraków)',
      address: 'ul. Karmelicka 1',
      postalCode: '31-128',
      city: 'Kraków',
      lat: 50.0647,
      lng: 19.945,
    },
  ];

  constructor(
    private readonly http: HttpService,
    private readonly config: ConfigService,
    private readonly flags: FeatureFlagsService,
    private readonly orlenPaczka: OrlenPaczkaService,
    private readonly market: MarketService,
  ) {}

  private providersCacheTtlMs() {
    return Number(
      this.config.get<string>('SHIPPING_PROVIDERS_CACHE_TTL_MS') ?? 21600000,
    );
  }

  private pointsCacheTtlMs() {
    return Number(
      this.config.get<string>('SHIPPING_POINTS_CACHE_TTL_MS') ?? 900000,
    );
  }

  private inpostApiBaseUrl() {
    return (
      this.config.get<string>('INPOST_API_BASE_URL') ??
      'https://api-shipx-pl.easypack24.net/v1'
    ).replace(/\/$/, '');
  }

  private inpostQueryCacheKey(options?: {
    postalCode?: string;
    city?: string;
    lat?: number;
    lng?: number;
    limit?: number;
  }) {
    return [
      options?.postalCode?.trim() ?? '',
      options?.city?.trim().toLowerCase() ?? '',
      String(options?.lat ?? ''),
      String(options?.lng ?? ''),
      String(options?.limit ?? ''),
    ].join('|');
  }

  private distanceScore(point: CarrierPoint, lat: number, lng: number) {
    return (point.lat - lat) ** 2 + (point.lng - lng) ** 2;
  }

  private normalizePointRow(raw: unknown): CarrierPoint | null {
    if (!raw || typeof raw !== 'object') return null;
    const row = raw as Record<string, unknown>;
    const id = scalarToString(row['name'] ?? row['id']).trim();
    const addrObj = (row['address'] ?? {}) as Record<string, unknown>;
    const locationObj = (row['location'] ?? {}) as Record<string, unknown>;
    const lat = Number(locationObj['latitude']);
    const lng = Number(locationObj['longitude']);
    if (!id || !Number.isFinite(lat) || !Number.isFinite(lng)) return null;
    return {
      id,
      name: scalarToString(row['name'] ?? id),
      address: scalarToString(addrObj['line1'] ?? addrObj['street']),
      postalCode: scalarToString(addrObj['post_code']),
      city: scalarToString(addrObj['city']),
      lat,
      lng,
    };
  }

  private fallbackInpostPoints(options?: {
    postalCode?: string;
    city?: string;
    lat?: number;
    lng?: number;
    limit?: number;
  }) {
    const limit = options?.limit ?? 12;
    let rows = [...this.inpostFallbackPoints];
    if (options?.postalCode) {
      const p = options.postalCode.slice(0, 2);
      rows = rows.filter((r) => r.postalCode.startsWith(p));
    } else if (options?.city) {
      const city = options.city.toLowerCase();
      rows = rows.filter((r) => r.city.toLowerCase().includes(city));
    }
    if (typeof options?.lat === 'number' && typeof options?.lng === 'number') {
      rows = rows.sort(
        (a, b) =>
          this.distanceScore(a, options.lat!, options.lng!) -
          this.distanceScore(b, options.lat!, options.lng!),
      );
    }
    return rows.slice(0, Math.max(1, limit));
  }

  listProviders() {
    if (!this.flags.integrationsShipping()) {
      return [];
    }
    const now = Date.now();
    if (this.providersCache && this.providersCache.expiresAt > now) {
      return this.providersCache.data;
    }
    const data = [
      {
        code: 'INPOST',
        name: 'InPost',
        supportsParcelLocker: true,
        supportsCourier: true,
        supportsMapPoints: true,
        apiConfigured: true,
      },
      {
        code: 'DPD',
        name: 'DPD',
        supportsParcelLocker: false,
        supportsCourier: true,
        supportsMapPoints: true,
        apiConfigured: Boolean(
          this.config.get<string>('DPD_API_BASE_URL')?.trim() &&
          this.config.get<string>('DPD_API_KEY')?.trim(),
        ),
      },
      {
        code: 'DHL',
        name: 'DHL eCommerce',
        supportsParcelLocker: true,
        supportsCourier: true,
        supportsMapPoints: true,
        apiConfigured: Boolean(
          this.config.get<string>('DHL_API_BASE_URL')?.trim() &&
          this.config.get<string>('DHL_API_KEY')?.trim(),
        ),
      },
      {
        code: 'POCZTA_POLSKA',
        name: 'Poczta Polska',
        supportsParcelLocker: false,
        supportsCourier: true,
        supportsMapPoints: true,
        apiConfigured: Boolean(
          this.config.get<string>('POCZTA_API_BASE_URL')?.trim() &&
          this.config.get<string>('POCZTA_POLSKA_API_KEY')?.trim(),
        ),
      },
      {
        code: 'ORLEN_PACZKA',
        name: 'ORLEN Paczka',
        supportsParcelLocker: true,
        supportsCourier: true,
        supportsMapPoints: true,
        apiConfigured: Boolean(
          this.config.get<string>('ORLEN_PACZKA_PARTNER_ID')?.trim() &&
          this.config.get<string>('ORLEN_PACZKA_PARTNER_KEY')?.trim(),
        ),
      },
    ];
    this.providersCache = {
      data,
      expiresAt: now + this.providersCacheTtlMs(),
    };
    return data;
  }

  async findInpostPoints(options?: {
    postalCode?: string;
    city?: string;
    lat?: number;
    lng?: number;
    limit?: number;
  }) {
    if (
      !this.flags.integrationsShipping() ||
      !this.flags.featureShippingInpost()
    ) {
      return [];
    }
    const now = Date.now();
    const key = this.inpostQueryCacheKey(options);
    const cached = this.inpostPointsCache.get(key);
    if (cached && cached.expiresAt > now) {
      return cached.data;
    }
    const limit = Math.max(1, options?.limit ?? 12);
    const query = new URLSearchParams({
      per_page: String(Math.min(70, Math.max(10, limit * 3))),
      page: '1',
      status: 'Operating',
      type: 'parcel_locker',
    });
    if (options?.postalCode?.trim()) {
      query.set('post_code', options.postalCode.trim());
    } else if (options?.city?.trim()) {
      query.set('city', options.city.trim());
    }
    const url = `${this.inpostApiBaseUrl()}/points?${query.toString()}`;
    try {
      const res = await firstValueFrom(
        this.http.get(url).pipe(
          catchError((error: unknown) => {
            throw error;
          }),
        ),
      );
      const data: unknown = res.data;
      const payload = data as { items?: unknown[] };
      const rawItems = Array.isArray(payload?.items) ? payload.items : [];
      let rows = rawItems
        .map((it) => this.normalizePointRow(it))
        .filter((it): it is CarrierPoint => Boolean(it));
      if (
        typeof options?.lat === 'number' &&
        typeof options?.lng === 'number'
      ) {
        rows = rows.sort(
          (a, b) =>
            this.distanceScore(a, options.lat!, options.lng!) -
            this.distanceScore(b, options.lat!, options.lng!),
        );
      }
      const trimmed = rows.slice(0, limit);
      if (trimmed.length > 0) {
        this.inpostPointsCache.set(key, {
          data: trimmed,
          expiresAt: now + this.pointsCacheTtlMs(),
        });
        return trimmed;
      }
    } catch (error) {
      this.logger.warn(
        `InPost points live fetch failed, using fallback: ${String(error)}`,
      );
    }
    const fallback = this.fallbackInpostPoints(options);
    this.inpostPointsCache.set(key, {
      data: fallback,
      expiresAt: now + Math.min(this.pointsCacheTtlMs(), 120000),
    });
    return fallback;
  }

  /**
   * Sugestie „pod nos” dla checkout — równolegle, live-first z cache.
   * Promise.allSettled: błąd jednego przewoźnika nie blokuje pozostałych.
   */
  async suggestPickupPoints(options?: {
    postalCode?: string;
    city?: string;
    lat?: number;
    lng?: number;
    limit?: number;
  }) {
    if (!this.flags.integrationsShipping()) {
      return {
        INPOST: [],
        DPD: [],
        DHL: [],
        POCZTA_POLSKA: [],
        ORLEN_PACZKA: [],
      };
    }
    const limit = options?.limit ?? 8;
    const base = { ...options, limit };
    const tasks: [string, () => Promise<CarrierPoint[]>][] = [
      ['INPOST', () => this.findInpostPoints(base)],
      ['DPD', () => this.findDpdPoints(base)],
      ['DHL', () => this.findDhlPoints(base)],
      ['POCZTA_POLSKA', () => this.findPocztaPoints(base)],
      ['ORLEN_PACZKA', () => this.findOrlenPoints(base)],
    ];
    const settled = await Promise.allSettled(tasks.map(([, fn]) => fn()));
    const out: Record<string, CarrierPoint[]> = {
      INPOST: [],
      DPD: [],
      DHL: [],
      POCZTA_POLSKA: [],
      ORLEN_PACZKA: [],
    };
    tasks.forEach(([code], i) => {
      const r = settled[i];
      if (r.status === 'fulfilled') {
        out[code] = r.value;
      } else {
        this.logger.warn(`[suggestPickupPoints] ${code}: ${String(r.reason)}`);
        out[code] = [];
      }
    });
    return out;
  }

  async findDpdPoints(options?: {
    postalCode?: string;
    city?: string;
    lat?: number;
    lng?: number;
    limit?: number;
  }) {
    if (!this.flags.integrationsShipping() || !this.flags.featureCarrierDpd()) {
      return [];
    }
    return this.findGenericCarrierPoints('DPD', options, {
      apiBase: this.config.get<string>('DPD_API_BASE_URL')?.trim(),
      apiKey: this.config.get<string>('DPD_API_KEY')?.trim(),
      path: this.config.get<string>('DPD_LOCKERS_PATH')?.trim() || '/lockers',
      fallback: this.dpdFallbackPoints,
    });
  }

  async findDhlPoints(options?: {
    postalCode?: string;
    city?: string;
    lat?: number;
    lng?: number;
    limit?: number;
  }) {
    if (!this.flags.integrationsShipping() || !this.flags.featureCarrierDhl()) {
      return [];
    }
    return this.findGenericCarrierPoints('DHL', options, {
      apiBase: this.config.get<string>('DHL_API_BASE_URL')?.trim(),
      apiKey: this.config.get<string>('DHL_API_KEY')?.trim(),
      path: this.config.get<string>('DHL_PICKUP_PATH')?.trim() || '/locations',
      fallback: this.dhlFallbackPoints,
    });
  }

  async findPocztaPoints(options?: {
    postalCode?: string;
    city?: string;
    lat?: number;
    lng?: number;
    limit?: number;
  }) {
    if (
      !this.flags.integrationsShipping() ||
      !this.flags.featureCarrierPoczta()
    ) {
      return [];
    }
    return this.findGenericCarrierPoints('POCZTA', options, {
      apiBase: this.config.get<string>('POCZTA_API_BASE_URL')?.trim(),
      apiKey: this.config.get<string>('POCZTA_POLSKA_API_KEY')?.trim(),
      path: this.config.get<string>('POCZTA_PICKUP_PATH')?.trim() || '/points',
      fallback: this.pocztaFallbackPoints,
    });
  }

  async findOrlenPoints(options?: {
    postalCode?: string;
    city?: string;
    lat?: number;
    lng?: number;
    limit?: number;
  }) {
    if (
      !this.flags.integrationsShipping() ||
      !this.flags.featureOrlenPaczka()
    ) {
      return [];
    }
    const now = Date.now();
    const key = this.carrierQueryCacheKey('ORLEN', options);
    const cached = this.carrierPointsCache.get(key);
    if (cached && cached.expiresAt > now) {
      return cached.data;
    }
    const limit = Math.max(1, options?.limit ?? 12);
    let rows = await this.orlenPaczka.fetchPoints();
    if (rows.length === 0) {
      let fb = this.filterFallbackByHint(this.orlenFallbackPoints, options);
      if (
        typeof options?.lat === 'number' &&
        typeof options?.lng === 'number'
      ) {
        fb = this.sortByDistance(fb, options.lat, options.lng);
      }
      const out = fb.slice(0, limit);
      this.carrierPointsCache.set(key, {
        data: out,
        expiresAt: now + Math.min(this.pointsCacheTtlMs(), 120000),
      });
      return out;
    }
    if (options?.postalCode?.trim()) {
      const digits = options.postalCode.replace(/\D/g, '').slice(0, 2);
      if (digits.length >= 2) {
        rows = rows.filter((r) =>
          r.postalCode.replace(/\D/g, '').startsWith(digits),
        );
      }
    }
    if (options?.city?.trim()) {
      const c = options.city.trim().toLowerCase();
      rows = rows.filter((r) => r.city.toLowerCase().includes(c));
    }
    if (typeof options?.lat === 'number' && typeof options?.lng === 'number') {
      rows = this.sortByDistance(rows, options.lat, options.lng);
    }
    const trimmed = rows.slice(0, limit);
    this.carrierPointsCache.set(key, {
      data: trimmed,
      expiresAt: now + this.pointsCacheTtlMs(),
    });
    return trimmed;
  }

  private carrierQueryCacheKey(
    carrier: string,
    options?: {
      postalCode?: string;
      city?: string;
      lat?: number;
      lng?: number;
      limit?: number;
    },
  ) {
    return `${carrier}|${this.inpostQueryCacheKey(options)}`;
  }

  private extractPointsArray(payload: unknown): unknown[] {
    if (Array.isArray(payload)) return payload;
    if (payload && typeof payload === 'object') {
      const p = payload as Record<string, unknown>;
      for (const key of [
        'items',
        'lockers',
        'points',
        'data',
        'parcelshops',
        'features',
        'locations',
        'placowki',
      ]) {
        const v = p[key];
        if (Array.isArray(v)) return v;
      }
    }
    return [];
  }

  private normalizeFlexiblePoint(raw: unknown): CarrierPoint | null {
    if (!raw || typeof raw !== 'object') return null;
    const r = raw as Record<string, unknown>;
    const id = scalarToString(
      r['id'] ?? r['lockerId'] ?? r['pni'] ?? r['name'],
    ).trim();
    const geo =
      (r['geoLocation'] as Record<string, unknown> | undefined) ??
      (r['location'] as Record<string, unknown> | undefined) ??
      (r['coordinates'] as Record<string, unknown> | undefined);
    const lat = Number(
      r['latitude'] ?? r['lat'] ?? geo?.['latitude'] ?? geo?.['lat'] ?? NaN,
    );
    const lng = Number(
      r['longitude'] ?? r['lng'] ?? geo?.['longitude'] ?? geo?.['lng'] ?? NaN,
    );
    let address = '';
    let postalCode = '';
    let city = '';
    const addr = r['address'];
    if (addr && typeof addr === 'object') {
      const a = addr as Record<string, unknown>;
      address = scalarToString(a['line1'] ?? a['street'] ?? a['streetName']);
      postalCode = scalarToString(a['postalCode'] ?? a['post_code']);
      city = scalarToString(a['city']);
    } else {
      address = scalarToString(r['address']);
      postalCode = scalarToString(r['postalCode'] ?? r['post_code']);
      city = scalarToString(r['city']);
    }
    if (!id || !Number.isFinite(lat) || !Number.isFinite(lng)) return null;
    return {
      id,
      name: scalarToString(r['name'] ?? r['label'] ?? id),
      address,
      postalCode,
      city,
      lat,
      lng,
    };
  }

  private sortByDistance(rows: CarrierPoint[], lat: number, lng: number) {
    return [...rows].sort(
      (a, b) =>
        this.distanceScore(a, lat, lng) - this.distanceScore(b, lat, lng),
    );
  }

  private filterFallbackByHint(
    rows: CarrierPoint[],
    options?: { postalCode?: string; city?: string },
  ) {
    let out = [...rows];
    if (options?.postalCode?.trim()) {
      const p = options.postalCode.trim().slice(0, 2);
      out = out.filter((r) => r.postalCode.startsWith(p));
    } else if (options?.city?.trim()) {
      const c = options.city.trim().toLowerCase();
      out = out.filter((r) => r.city.toLowerCase().includes(c));
    }
    return out;
  }

  private async findGenericCarrierPoints(
    carrier: string,
    options:
      | {
          postalCode?: string;
          city?: string;
          lat?: number;
          lng?: number;
          limit?: number;
        }
      | undefined,
    cfg: {
      apiBase?: string;
      apiKey?: string;
      path: string;
      fallback: CarrierPoint[];
    },
  ): Promise<CarrierPoint[]> {
    const now = Date.now();
    const key = this.carrierQueryCacheKey(carrier, options);
    const cached = this.carrierPointsCache.get(key);
    if (cached && cached.expiresAt > now) {
      return cached.data;
    }
    const limit = Math.max(1, options?.limit ?? 12);
    const base = cfg.apiBase?.replace(/\/$/, '');
    const hasLive = Boolean(base && cfg.apiKey);

    if (hasLive) {
      try {
        const path = cfg.path.startsWith('/') ? cfg.path : `/${cfg.path}`;
        const u = new URL(`${base}${path}`);
        if (options?.postalCode?.trim()) {
          u.searchParams.set('postalCode', options.postalCode.trim());
        }
        if (options?.city?.trim()) {
          u.searchParams.set('city', options.city.trim());
        }
        if (
          typeof options?.lat === 'number' &&
          typeof options?.lng === 'number'
        ) {
          u.searchParams.set('startPointLatitude', String(options.lat));
          u.searchParams.set('startPointLongitude', String(options.lng));
          u.searchParams.set('radius', '15000');
        }
        const { data } = await firstValueFrom(
          this.http.get<unknown>(u.toString(), {
            headers: {
              Accept: 'application/json',
              Authorization: `Bearer ${cfg.apiKey}`,
            },
          }),
        );
        const rawItems = this.extractPointsArray(data);
        let rows = rawItems
          .map((it) => this.normalizeFlexiblePoint(it))
          .filter((it): it is CarrierPoint => Boolean(it));
        if (
          typeof options?.lat === 'number' &&
          typeof options?.lng === 'number'
        ) {
          rows = this.sortByDistance(rows, options.lat, options.lng);
        }
        const trimmed = rows.slice(0, limit);
        if (trimmed.length > 0) {
          this.carrierPointsCache.set(key, {
            data: trimmed,
            expiresAt: now + this.pointsCacheTtlMs(),
          });
          return trimmed;
        }
      } catch (error) {
        this.logger.warn(
          `${carrier} points live fetch failed, using fallback: ${String(error)}`,
        );
      }
    }

    let fb = this.filterFallbackByHint(cfg.fallback, options);
    if (typeof options?.lat === 'number' && typeof options?.lng === 'number') {
      fb = this.sortByDistance(fb, options.lat, options.lng);
    }
    const out = fb.slice(0, limit);
    this.carrierPointsCache.set(key, {
      data: out,
      expiresAt: now + Math.min(this.pointsCacheTtlMs(), 120000),
    });
    return out;
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
      currency: this.market.primaryCurrency(),
      price: freeShipping ? 0 : Number((base + surcharge).toFixed(2)),
      freeShippingThreshold: 350,
      estimatedDays: input.shipmentType === 'PARCEL_LOCKER' ? '1-2' : '1-3',
      /** Cenniki umowne — podłącz endpointy przewoźnika przez env, gdy dostępne. */
      mode: 'dev-simulation' as const,
      liveRatesConfigured: false,
    };
  }
}
