import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

/**
 * Flagi funkcji — małe „wyłączniki” integracji bez przebudowy kodu.
 * Domyślnie włączone (true), wyłączenie: FEATURE_X=false
 */
@Injectable()
export class FeatureFlagsService {
  constructor(private readonly config: ConfigService) {}

  /**
   * @param key pełny klucz env, np. FEATURE_INTEGRATIONS_SHIPPING
   * @param defaultValue gdy zmienna nieustawiona
   */
  isTruthy(key: string, defaultValue = true): boolean {
    const v = this.config.get<string>(key);
    if (v === undefined || v === null || v === '') return defaultValue;
    const t = v.trim().toLowerCase();
    if (t === 'false' || t === '0' || t === 'no' || t === 'off') return false;
    if (t === 'true' || t === '1' || t === 'yes' || t === 'on') return true;
    return defaultValue;
  }

  /** Master: cały moduł /shipping i sugestie przewoźników */
  integrationsShipping(): boolean {
    return this.isTruthy('FEATURE_INTEGRATIONS_SHIPPING', true);
  }

  featureShippingInpost(): boolean {
    return this.isTruthy('FEATURE_SHIPPING_INPOST', true);
  }

  featureOrlenPaczka(): boolean {
    return this.isTruthy('FEATURE_ORLEN_PACZKA', true);
  }

  featureCarrierDpd(): boolean {
    return this.isTruthy('FEATURE_SHIPPING_DPD', true);
  }

  featureCarrierDhl(): boolean {
    return this.isTruthy('FEATURE_SHIPPING_DHL', true);
  }

  featureCarrierPoczta(): boolean {
    return this.isTruthy('FEATURE_SHIPPING_POCZTA', true);
  }
}
