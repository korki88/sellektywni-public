import { IsOptional, IsString } from 'class-validator';

export class SubmitCartDto {
  @IsOptional()
  @IsString()
  ownerKey?: string;
}
