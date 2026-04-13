import { PaymentMethod, ShippingMethod } from '@prisma/client';
import {
  IsArray,
  IsBoolean,
  IsEmail,
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';

class FinalizeOrderItemDto {
  @IsString()
  productId!: string;

  @IsInt()
  @Min(1)
  quantity!: number;
}

class ShippingTargetDto {
  @IsOptional()
  @IsString()
  addressBookEntryId?: string;

  @IsOptional()
  @IsString()
  label?: string;

  @IsOptional()
  @IsString()
  recipientName?: string;

  @IsOptional()
  @IsString()
  @Matches(/^\+?[0-9\s-]{7,20}$/)
  phone?: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsString()
  country?: string;

  @IsOptional()
  @IsString()
  @Matches(/^\d{2}-\d{3}$/)
  postalCode?: string;

  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @IsString()
  street?: string;

  @IsOptional()
  @IsString()
  buildingNumber?: string;

  @IsOptional()
  @IsString()
  apartmentNumber?: string;

  @IsOptional()
  @IsString()
  parcelLockerId?: string;

  @IsOptional()
  @IsString()
  parcelLockerLabel?: string;
}

export class FinalizeOrderDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => FinalizeOrderItemDto)
  items!: FinalizeOrderItemDto[];

  @IsEnum(PaymentMethod)
  paymentMethod!: PaymentMethod;

  @IsEnum(ShippingMethod)
  shippingMethod!: ShippingMethod;

  @ValidateNested()
  @Type(() => ShippingTargetDto)
  shippingTarget!: ShippingTargetDto;

  @IsOptional()
  @IsBoolean()
  saveToAddressBook?: boolean;
}
