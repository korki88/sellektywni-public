import { Injectable } from '@nestjs/common';
import { Prisma, type AuditLog } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

type LogActionInput = {
  userId: string;
  userEmail: string;
  action: string;
  resourceType: string;
  resourceId: string;
  oldValue?: Prisma.InputJsonValue;
  newValue?: Prisma.InputJsonValue;
  ipAddress?: string | null;
};

type ListAuditLogsOptions = {
  offset: number;
  limit: number;
  userId?: string;
  userEmail?: string;
  action?: string;
  resourceType?: string;
};

@Injectable()
export class AuditService {
  constructor(private readonly prisma: PrismaService) {}

  async logAction(input: LogActionInput): Promise<AuditLog> {
    return this.prisma.auditLog.create({
      data: {
        userId: input.userId,
        userEmail:
          input.userEmail.trim() || `user-${input.userId}@unknown.local`,
        action: input.action.trim().toUpperCase(),
        resourceType: input.resourceType.trim().toUpperCase() || 'UNKNOWN',
        resourceId: input.resourceId.trim() || 'UNKNOWN',
        oldValue: input.oldValue,
        newValue: input.newValue,
        ipAddress: input.ipAddress?.trim() || null,
      },
    });
  }

  async listLogs(options: ListAuditLogsOptions): Promise<{
    total: number;
    offset: number;
    limit: number;
    rows: AuditLog[];
  }> {
    const where: Prisma.AuditLogWhereInput = {
      ...(options.userId ? { userId: options.userId } : {}),
      ...(options.userEmail
        ? {
            userEmail: {
              contains: options.userEmail,
              mode: 'insensitive',
            },
          }
        : {}),
      ...(options.action
        ? {
            action: {
              contains: options.action.toUpperCase(),
              mode: 'insensitive',
            },
          }
        : {}),
      ...(options.resourceType
        ? {
            resourceType: {
              equals: options.resourceType.toUpperCase(),
            },
          }
        : {}),
    };

    const [rows, total] = await Promise.all([
      this.prisma.auditLog.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: options.offset,
        take: options.limit,
      }),
      this.prisma.auditLog.count({ where }),
    ]);

    return {
      total,
      offset: options.offset,
      limit: options.limit,
      rows,
    };
  }
}
