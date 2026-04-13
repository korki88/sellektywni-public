import { HttpService } from '@nestjs/axios';
import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PaymentMethod, PaymentProvider, PaymentStatus } from '@prisma/client';
import { createHash } from 'crypto';
import { firstValueFrom } from 'rxjs';

type InitPaymentInput = {
  paymentMethod: PaymentMethod;
  totalAmount: number;
  userId: string;
  orderReference: string;
  returnUrl?: string;
};

@Injectable()
export class PaymentsService {
  private readonly logger = new Logger(PaymentsService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly http: HttpService,
  ) {}

  async initializePayment(input: InitPaymentInput): Promise<{
    paymentProvider: PaymentProvider;
    paymentStatus: PaymentStatus;
    paymentReference: string | null;
    paymentSessionUrl: string | null;
    paymentBankAccount: string | null;
    paymentDetails: Record<string, unknown>;
  }> {
    const reference = input.orderReference;
    if (input.paymentMethod === PaymentMethod.BANK_TRANSFER) {
      return {
        paymentProvider: PaymentProvider.BANK_TRANSFER_MOCK,
        paymentStatus: PaymentStatus.PENDING,
        paymentReference: reference,
        paymentSessionUrl: null,
        paymentBankAccount: '11 1111 1111 1111 1111 1111 1111',
        paymentDetails: {
          accountHolder: 'SELLEKTYWNI.PL DEV PAYMENTS',
          title: `Zamówienie ${reference}`,
          amount: input.totalAmount.toFixed(2),
          currency: 'PLN',
          mode: 'dev-simulation',
        },
      };
    }
    if (input.paymentMethod === PaymentMethod.CASH_ON_DELIVERY) {
      return {
        paymentProvider: PaymentProvider.CASH_ON_DELIVERY,
        paymentStatus: PaymentStatus.COD_PENDING,
        paymentReference: reference,
        paymentSessionUrl: null,
        paymentBankAccount: null,
        paymentDetails: {
          note: 'Płatność przy odbiorze',
          currency: 'PLN',
        },
      };
    }

    const p24MerchantId = this.config.get<string>('P24_MERCHANT_ID')?.trim();
    const p24PosId =
      this.config.get<string>('P24_POS_ID')?.trim() ?? p24MerchantId ?? '';
    const p24Crc = this.config.get<string>('P24_CRC')?.trim();
    const p24SandboxBase =
      this.config.get<string>('P24_SANDBOX_BASE_URL') ??
      'https://sandbox.przelewy24.pl';
    const base = p24SandboxBase.replace(/\/$/, '');
    const p24Configured = Boolean(p24MerchantId && p24Crc && p24PosId);

    if (p24Configured) {
      const live = await this.registerP24Transaction(base, {
        sessionId: reference,
        merchantId: p24MerchantId!,
        posId: p24PosId,
        crc: p24Crc!,
        amountPln: input.totalAmount,
        email:
          this.config.get<string>('P24_CHECKOUT_EMAIL')?.trim() ??
          'checkout@example.com',
        returnUrl:
          input.returnUrl?.trim() ||
          this.config.get<string>('P24_URL_RETURN')?.trim() ||
          `${base}/payment/return`,
        description: `Zamówienie ${reference}`,
      });
      if (live) {
        return {
          paymentProvider: PaymentProvider.PRZELEWY24,
          paymentStatus: PaymentStatus.PENDING,
          paymentReference: reference,
          paymentSessionUrl: live.sessionUrl,
          paymentBankAccount: null,
          paymentDetails: {
            provider: 'Przelewy24',
            providerMode: 'live-register',
            amount: input.totalAmount.toFixed(2),
            currency: 'PLN',
            customerId: input.userId,
          },
        };
      }
      this.logger.warn(
        'P24: trnRegister nie powiodło się — używam trybu symulacji sandbox',
      );
    }

    return {
      paymentProvider: PaymentProvider.PRZELEWY24,
      paymentStatus: PaymentStatus.PENDING,
      paymentReference: reference,
      paymentSessionUrl: `${base}/trnRequest/${encodeURIComponent(reference)}`,
      paymentBankAccount: null,
      paymentDetails: {
        provider: 'Przelewy24',
        providerMode: p24Configured ? 'sandbox-fallback' : 'sandbox-simulation',
        merchantConfigured: p24Configured,
        merchantHint: p24Configured
          ? 'Sprawdź CRC, POS ID i URL zwrotu (P24_URL_RETURN).'
          : 'Ustaw P24_MERCHANT_ID, P24_POS_ID i P24_CRC aby włączyć rejestrację trnRegister.',
        amount: input.totalAmount.toFixed(2),
        currency: 'PLN',
        customerId: input.userId,
      },
    };
  }

  /**
   * Klasyk P24: POST trnRegister (form), podpis MD5:
   * sessionId|merchantId|amount|currency|crc
   * amount w groszach (int).
   */
  private async registerP24Transaction(
    baseUrl: string,
    opts: {
      sessionId: string;
      merchantId: string;
      posId: string;
      crc: string;
      amountPln: number;
      email: string;
      returnUrl: string;
      description: string;
    },
  ): Promise<{ token: string; sessionUrl: string } | null> {
    const sessionId = opts.sessionId
      .replace(/[^a-zA-Z0-9_-]/g, '')
      .slice(0, 100);
    if (!sessionId) return null;
    const amount = Math.round(opts.amountPln * 100);
    if (amount <= 0) return null;
    const currency = 'PLN';
    const sign = createHash('md5')
      .update(
        `${sessionId}|${opts.merchantId}|${amount}|${currency}|${opts.crc}`,
      )
      .digest('hex');

    const body = new URLSearchParams({
      p24_session_id: sessionId,
      p24_merchant_id: opts.merchantId,
      p24_pos_id: opts.posId,
      p24_amount: String(amount),
      p24_currency: currency,
      p24_description: opts.description.slice(0, 1024),
      p24_email: opts.email,
      p24_country: 'PL',
      p24_url_return: opts.returnUrl,
      p24_api_version: '3.2',
      p24_sign: sign,
    });
    const statusUrl = this.config.get<string>('P24_URL_STATUS')?.trim();
    if (statusUrl) {
      body.set('p24_url_status', statusUrl);
    }

    try {
      const res = await firstValueFrom(
        this.http.post(`${baseUrl}/trnRegister`, body.toString(), {
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          responseType: 'text',
        }),
      );
      const data: unknown = res.data;
      const raw = typeof data === 'string' ? data : String(data);
      const parsed = this.parseP24FormBody(raw);
      const err = parsed['error'];
      const token = parsed['token'];
      if (err && err !== '0') {
        this.logger.warn(
          `P24 trnRegister error=${err} body=${raw.slice(0, 500)}`,
        );
        return null;
      }
      if (!token) {
        this.logger.warn(`P24 trnRegister brak tokena: ${raw.slice(0, 500)}`);
        return null;
      }
      return {
        token,
        sessionUrl: `${baseUrl}/trnRequest/${token}`,
      };
    } catch (e) {
      this.logger.warn(`P24 trnRegister wyjątek: ${String(e)}`);
      return null;
    }
  }

  private parseP24FormBody(body: string): Record<string, string> {
    const out: Record<string, string> = {};
    const clean = body.trim().replace(/^\?/, '');
    const params = new URLSearchParams(clean);
    for (const [k, v] of params.entries()) {
      out[k] = v;
    }
    return out;
  }
}
