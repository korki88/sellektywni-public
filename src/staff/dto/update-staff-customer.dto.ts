import { ProfileRank } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class UpdateStaffCustomerDto {
  @IsOptional()
  @IsEnum(ProfileRank)
  rank?: ProfileRank;

  /** Ustawia dokładną liczbę punktów (ma pierwszeństwo przed addPoints). */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  setPoints?: number;

  /** Dodaje punkty do aktualnego stanu. */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  addPoints?: number;

  /** Segmentacja (DEFAULT, VIP, CHURN_RISK, …). */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  customerSegment?: string;
}
