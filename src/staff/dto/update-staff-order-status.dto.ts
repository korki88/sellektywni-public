import { CustomerOrderStatus } from '@prisma/client';
import { IsEnum } from 'class-validator';

export class UpdateStaffOrderStatusDto {
  @IsEnum(CustomerOrderStatus)
  status!: CustomerOrderStatus;
}
