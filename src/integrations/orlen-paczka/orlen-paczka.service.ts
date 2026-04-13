import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as soap from 'soap';

import { scalarToString } from '../../lib/scalar-string';
import type { CarrierPoint } from '../../shipping/types/carrier-point';

function rejectAsError(err: unknown): Error {
  return err instanceof Error ? err : new Error(String(err));
}

/**
 * ORLEN Paczka — API SOAP (WSDL). Izolacja: błędy SOAP nie propagują na resztę aplikacji.
 * @see https://www.orlenpaczka.pl/integracja-z-orlen-paczka/
 */
@Injectable()
export class OrlenPaczkaService {
  private readonly logger = new Logger(OrlenPaczkaService.name);

  constructor(private readonly config: ConfigService) {}

  private wsdlUrl(): string {
    const custom = this.config.get<string>('ORLEN_PACZKA_WSDL_URL')?.trim();
    if (custom) return custom;
    const useTest =
      this.config.get<string>('ORLEN_PACZKA_USE_TEST') !== 'false';
    return useTest
      ? 'https://api-test.orlenpaczka.pl/WebServicePwR/WebServicePwR.asmx?WSDL'
      : 'https://api.orlenpaczka.pl/WebServicePwRProd/WebServicePwR.asmx?wsdl';
  }

  private credentials(): { partnerId: string; partnerKey: string } | null {
    const partnerId = this.config
      .get<string>('ORLEN_PACZKA_PARTNER_ID')
      ?.trim();
    const partnerKey = this.config
      .get<string>('ORLEN_PACZKA_PARTNER_KEY')
      ?.trim();
    if (!partnerId || !partnerKey) return null;
    return { partnerId, partnerKey };
  }

  /**
   * Pobiera listę punktów z SOAP (jeśli skonfigurowano) i mapuje do CarrierPoint.
   * Nigdy nie rzuca — przy błędzie zwraca [].
   */
  async fetchPoints(): Promise<CarrierPoint[]> {
    const cred = this.credentials();
    if (!cred) {
      return [];
    }
    try {
      const client = await this.createClient();
      const methodName =
        this.config.get<string>('ORLEN_PACZKA_SOAP_METHOD')?.trim() ||
        'GiveMeAllRUCHWithFilled';
      const fn = (client as Record<string, unknown>)[methodName];
      if (typeof fn !== 'function') {
        this.logger.warn(`Orlen SOAP: brak metody ${methodName}`);
        return [];
      }
      const args = this.buildSoapArgs(cred.partnerId, cred.partnerKey);
      const result: unknown = await new Promise((resolve, reject) => {
        (fn as (a: unknown, cb: (e: unknown, r: unknown) => void) => void)(
          args,
          (err: unknown, r: unknown) =>
            err ? reject(rejectAsError(err)) : resolve(r),
        );
      });
      const raw = this.collectPointLikeObjects(result);
      const mapped = raw
        .map((o) => this.normalizeOrlenRow(o))
        .filter((p): p is CarrierPoint => Boolean(p));
      return mapped;
    } catch (e) {
      this.logger.warn(`Orlen Paczka SOAP: ${String(e)}`);
      return [];
    }
  }

  private buildSoapArgs(
    partnerId: string,
    partnerKey: string,
  ): Record<string, string> {
    return {
      PartnerID: partnerId,
      PartnerKey: partnerKey,
    };
  }

  private createClient(): Promise<import('soap').Client> {
    return new Promise((resolve, reject) => {
      soap.createClient(
        this.wsdlUrl(),
        (err: unknown, client: import('soap').Client) => {
          if (err) reject(rejectAsError(err));
          else resolve(client);
        },
      );
    });
  }

  /** Rekurencyjnie zbiera obiekty przypominające wiersz punktu (DestinationCode + współrzędne). */
  private collectPointLikeObjects(result: unknown): Record<string, unknown>[] {
    const out: Record<string, unknown>[] = [];
    const visit = (x: unknown) => {
      if (!x || typeof x !== 'object') return;
      const o = x as Record<string, unknown>;
      const dest = o['DestinationCode'] ?? o['destinationCode'];
      const lat = o['Latitude'] ?? o['latitude'];
      const lng = o['Longitude'] ?? o['longitude'];
      if (dest && lat !== undefined && lng !== undefined) {
        out.push(o);
        return;
      }
      for (const v of Object.values(o)) {
        if (Array.isArray(v)) v.forEach(visit);
        else if (v && typeof v === 'object') visit(v);
      }
    };
    visit(result);
    return out;
  }

  private normalizeOrlenRow(o: Record<string, unknown>): CarrierPoint | null {
    const id = scalarToString(
      o['DestinationCode'] ?? o['destinationCode'],
    ).trim();
    const lat = Number(
      scalarToString(o['Latitude'] ?? o['latitude'])
        .replace(',', '.')
        .trim(),
    );
    const lng = Number(
      scalarToString(o['Longitude'] ?? o['longitude'])
        .replace(',', '.')
        .trim(),
    );
    if (!id || !Number.isFinite(lat) || !Number.isFinite(lng)) return null;
    const street = scalarToString(o['StreetName'] ?? o['streetName']);
    const city = scalarToString(o['City'] ?? o['city']);
    const zip = scalarToString(
      o['ZipCode'] ?? o['PostalCode'] ?? o['postalCode'],
    );
    return {
      id,
      name: id,
      address: street,
      postalCode: zip,
      city,
      lat,
      lng,
    };
  }
}
