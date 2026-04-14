import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsNumber,
  IsOptional,
  IsString,
  Min,
  MinLength,
} from 'class-validator';

export class CreateGiftCardDto {
  /** Puste = wygeneruj kod automatycznie */
  @IsOptional()
  @IsString()
  @MinLength(4)
  code?: string;

  @Type(() => Number)
  @IsNumber()
  @Min(0.01)
  initialAmount!: number;

  @IsOptional()
  @IsString()
  @MinLength(3)
  currency?: string;

  @IsOptional()
  @IsString()
  expiresAtIso?: string;

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}
