import { IsInt, IsOptional, IsString, Min, ValidateIf } from 'class-validator';

export class CreateOrderDto {
  @ValidateIf((o: CreateOrderDto) => !o.idDotykacka)
  @IsString({ message: 'productId musi być tekstem' })
  productId?: string;

  @ValidateIf((o: CreateOrderDto) => !o.productId)
  @IsString()
  idDotykacka?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  quantity?: number;

  @IsOptional()
  @IsString()
  ownerKey?: string;
}
