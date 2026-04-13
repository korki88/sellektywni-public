import { IsString, MinLength } from 'class-validator';

export class AddSupportMessageDto {
  @IsString()
  @MinLength(1)
  body!: string;
}
