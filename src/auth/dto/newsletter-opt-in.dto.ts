import { IsBoolean } from 'class-validator';

export class NewsletterOptInDto {
  @IsBoolean()
  optIn!: boolean;
}
