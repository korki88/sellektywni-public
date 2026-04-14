import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';

@Injectable()
export class FirebasePushService {
  private readonly logger = new Logger(FirebasePushService.name);
  private initialized = false;

  constructor(private readonly config: ConfigService) {}

  private ensureInitialized(): boolean {
    if (this.initialized) return true;
    if (getApps().length > 0) {
      this.initialized = true;
      return true;
    }

    const base64 = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_BASE64');
    const rawJson = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT_JSON');
    const source = base64?.trim()
      ? Buffer.from(base64, 'base64').toString('utf8')
      : rawJson?.trim() || '';
    if (!source) {
      this.logger.debug('Firebase push disabled: missing service account env');
      return false;
    }

    try {
      const parsed = JSON.parse(source) as {
        project_id: string;
        client_email: string;
        private_key: string;
      };
      initializeApp({
        credential: cert({
          projectId: parsed.project_id,
          clientEmail: parsed.client_email,
          privateKey: parsed.private_key,
        }),
      });
      this.initialized = true;
      return true;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.warn(`Firebase init failed: ${message}`);
      return false;
    }
  }

  async sendOwnerProfitGuardNotification(input: {
    proposalId: string;
    productName: string;
    suggestedDiscountPercent: number;
  }): Promise<void> {
    if (!this.ensureInitialized()) return;
    const topic =
      this.config.get<string>('FIREBASE_OWNER_TOPIC')?.trim() || 'owner';
    try {
      await getMessaging().send({
        topic,
        notification: {
          title: 'Profit Guard: nowa rekomendacja',
          body: `${input.productName} · obniżka ${input.suggestedDiscountPercent.toFixed(2)}%`,
        },
        data: {
          type: 'PROFIT_GUARD_NEW_PROPOSAL',
          proposalId: input.proposalId,
          productName: input.productName,
          suggestedDiscountPercent: input.suggestedDiscountPercent.toFixed(2),
        },
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.warn(`Firebase push send failed: ${message}`);
    }
  }
}
