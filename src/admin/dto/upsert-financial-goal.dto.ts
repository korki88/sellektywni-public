import { Type } from 'class-transformer';
import {
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
} from 'class-validator';

export class UpsertFinancialGoalDto {
  @Matches(/^\d{4}-\d{2}$/, {
    message: 'month musi mieć format YYYY-MM',
  })
  month!: string;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  revenueTarget!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  profitTarget!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  fixedCosts!: number;

  @Type(() => Number)
  @IsNumber()
  @Min(0)
  burnRate!: number;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;
}
