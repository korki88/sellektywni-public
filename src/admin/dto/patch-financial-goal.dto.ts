import { Type } from 'class-transformer';
import {
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
} from 'class-validator';

export class PatchFinancialGoalDto {
  @IsOptional()
  @Matches(/^\d{4}-\d{2}$/, {
    message: 'month musi mieć format YYYY-MM',
  })
  month?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  revenueTarget?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  profitTarget?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  fixedCosts?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  burnRate?: number;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;
}
