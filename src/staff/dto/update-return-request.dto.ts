import { IsIn, IsOptional, IsString } from 'class-validator';
import { ReturnRequestStatus } from '@prisma/client';

const statuses: ReturnRequestStatus[] = [
  'PENDING',
  'APPROVED',
  'REJECTED',
  'RECEIVED',
];

export class UpdateReturnRequestDto {
  @IsIn(statuses)
  status!: ReturnRequestStatus;

  @IsOptional()
  @IsString()
  staffNote?: string;
}
