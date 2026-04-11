import { IsOptional, IsString, IsUUID, ValidateIf } from 'class-validator';

export class CreateOrderDto {
  @ValidateIf((o: CreateOrderDto) => !o.idDotykacka)
  @IsUUID('4', { message: 'productId musi być prawidłowym UUID' })
  productId?: string;

  @ValidateIf((o: CreateOrderDto) => !o.productId)
  @IsString()
  idDotykacka?: string;
}
