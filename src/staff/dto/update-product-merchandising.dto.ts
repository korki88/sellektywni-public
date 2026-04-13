import { IsBoolean, IsOptional, IsString, MaxLength } from 'class-validator';

export class UpdateProductMerchandisingDto {
  @IsOptional()
  @IsBoolean()
  isFeatured?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(512)
  subtitle?: string | null;
}
