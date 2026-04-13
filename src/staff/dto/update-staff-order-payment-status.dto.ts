import { PaymentStatus } from '@prisma/client';
import { IsEnum } from 'class-validator';

export class UpdateStaffOrderPaymentStatusDto {
  @IsEnum(PaymentStatus)
  paymentStatus!: PaymentStatus;
}
