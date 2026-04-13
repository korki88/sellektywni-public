import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PaymentMethod, PaymentProvider, PaymentStatus } from '@prisma/client';

type InitPaymentInput = {
  paymentMethod: PaymentMethod;
  totalAmount: number;
  userId: string;
  orderReference: string;
  returnUrl?: string;
};

@Injectable()
export class PaymentsService {
  constructor(private readonly config: ConfigService) {}

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

    // Przelewy24: sandbox-ready fallback. Real registration requires merchantId/CRC in env.
    const p24MerchantId = this.config.get<string>('P24_MERCHANT_ID');
    const p24Crc = this.config.get<string>('P24_CRC');
    const p24SandboxBase =
      this.config.get<string>('P24_SANDBOX_BASE_URL') ?? 'https://sandbox.przelewy24.pl';
    const p24Enabled = Boolean(p24MerchantId?.trim() && p24Crc?.trim());

    return {
      paymentProvider: PaymentProvider.PRZELEWY24,
      paymentStatus: PaymentStatus.PENDING,
      paymentReference: reference,
      paymentSessionUrl: `${p24SandboxBase.replace(/\/$/, '')}/trnRequest/${reference}`,
      paymentBankAccount: null,
      paymentDetails: {
        provider: 'Przelewy24',
        providerMode: p24Enabled ? 'sandbox-configured' : 'sandbox-simulation',
        merchantConfigured: p24Enabled,
        merchantHint: p24Enabled
          ? 'Użyto konfiguracji sandbox Przelewy24.'
          : 'Ustaw P24_MERCHANT_ID i P24_CRC aby włączyć realną rejestrację transakcji.',
        amount: input.totalAmount.toFixed(2),
        currency: 'PLN',
        customerId: input.userId,
      },
    };
  }
}
