import { IsBoolean } from 'class-validator';

export class SetGiftCardActiveDto {
  @IsBoolean()
  active!: boolean;
}
