import { Injectable } from '@nestjs/common';
import { AuditService } from '../audit/audit.service';

type ListAuditLogsOptions = {
  offset: number;
  limit: number;
  userId?: string;
  userEmail?: string;
  action?: string;
  resourceType?: string;
};

@Injectable()
export class StaffAuditService {
  constructor(private readonly audit: AuditService) {}

  async listLogs({
    offset,
    limit,
    userId,
    userEmail,
    action,
    resourceType,
  }: ListAuditLogsOptions) {
    return this.audit.listLogs({
      offset,
      limit,
      userId,
      userEmail,
      action,
      resourceType,
    });
  }
}
