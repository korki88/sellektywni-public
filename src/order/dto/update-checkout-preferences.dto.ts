import { PaymentMethod, ShippingMethod } from '@prisma/client';
import { IsEnum, IsOptional, IsString } from 'class-validator';

export class UpdateCheckoutPreferencesDto {
  @IsOptional()
  @IsEnum(PaymentMethod)
  preferredPaymentMethod?: PaymentMethod;

  @IsOptional()
  @IsEnum(ShippingMethod)
  preferredShippingMethod?: ShippingMethod;

  @IsOptional()
  @IsString()
  preferredAddressId?: string;
}
