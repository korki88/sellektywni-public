import { IsBoolean } from 'class-validator';

export class PatchExperimentActiveDto {
  @IsBoolean()
  active!: boolean;
}
