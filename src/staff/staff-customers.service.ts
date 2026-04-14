import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { AuditService } from '../audit/audit.service';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateStaffCustomerDto } from './dto/update-staff-customer.dto';

type AuditActor = {
  userId: string;
  userEmail?: string | null;
  ipAddress?: string | null;
};

@Injectable()
export class StaffCustomersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  async getProfile(userId: string) {
    const p = await this.prisma.profile.findUnique({ where: { userId } });
    if (!p) {
      throw new NotFoundException('Profil klienta nie istnieje');
    }
    return p;
  }

  async updateProfile(
    userId: string,
    dto: UpdateStaffCustomerDto,
    actor: AuditActor,
  ) {
    const exists = await this.prisma.profile.findUnique({
      where: { userId },
      select: {
        userId: true,
        email: true,
        rank: true,
        points: true,
        customerSegment: true,
      },
    });
    if (!exists) {
      throw new NotFoundException('Profil klienta nie istnieje');
    }

    if (dto.setPoints !== undefined && dto.addPoints !== undefined) {
      throw new BadRequestException(
        'Podaj albo setPoints, albo addPoints, nie oba naraz.',
      );
    }

    const data: Prisma.ProfileUpdateInput = {};
    if (dto.rank !== undefined) {
      data.rank = dto.rank;
    }
    if (dto.setPoints !== undefined) {
      data.points = dto.setPoints;
    } else if (dto.addPoints !== undefined) {
      data.points = { increment: dto.addPoints };
    }
    if (dto.customerSegment !== undefined) {
      data.customerSegment =
        dto.customerSegment.trim().slice(0, 64) || 'DEFAULT';
    }

    if (Object.keys(data).length === 0) {
      throw new BadRequestException('Brak pól do aktualizacji');
    }

    const updated = await this.prisma.profile.update({
      where: { userId },
      data,
    });

    if (exists.rank !== updated.rank) {
      await this.audit.logAction({
        userId: actor.userId,
        userEmail:
          actor.userEmail?.trim() || `user-${actor.userId}@unknown.local`,
        action: 'CHANGE_RANK',
        resourceType: 'CUSTOMER',
        resourceId: userId,
        oldValue: {
          rank: exists.rank,
          customerEmail: exists.email,
        },
        newValue: {
          rank: updated.rank,
          customerEmail: updated.email,
        },
        ipAddress: actor.ipAddress ?? null,
      });
    }

    if (exists.points !== updated.points) {
      await this.audit.logAction({
        userId: actor.userId,
        userEmail:
          actor.userEmail?.trim() || `user-${actor.userId}@unknown.local`,
        action: 'CHANGE_POINTS',
        resourceType: 'CUSTOMER',
        resourceId: userId,
        oldValue: {
          points: exists.points,
          customerEmail: exists.email,
        },
        newValue: {
          points: updated.points,
          customerEmail: updated.email,
        },
        ipAddress: actor.ipAddress ?? null,
      });
    }

    return updated;
  }
}
