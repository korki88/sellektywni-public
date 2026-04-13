import { IsArray, IsString } from 'class-validator';

export class UpdateStaffPermissionsDto {
  @IsArray()
  @IsString({ each: true })
  permissions!: string[];
}
