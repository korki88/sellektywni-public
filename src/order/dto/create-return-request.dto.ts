import { IsString, IsUUID, MinLength } from 'class-validator';

export class CreateReturnRequestDto {
  @IsUUID()
  orderId!: string;

  @IsString()
  @MinLength(8, { message: 'Opisz powód zwrotu (min. 8 znaków).' })
  reason!: string;
}
