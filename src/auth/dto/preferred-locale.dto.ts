import { IsString, MinLength } from 'class-validator';

export class PreferredLocaleDto {
  @IsString()
  @MinLength(2)
  locale!: string;
}
