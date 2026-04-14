import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateStaffCustomerDto } from './dto/update-staff-customer.dto';

@Injectable()
export class StaffCustomersService {
  constructor(private readonly prisma: PrismaService) {}

  async getProfile(userId: string) {
    const p = await this.prisma.profile.findUnique({ where: { userId } });
    if (!p) {
      throw new NotFoundException('Profil klienta nie istnieje');
    }
    return p;
  }

  async updateProfile(userId: string, dto: UpdateStaffCustomerDto) {
    const exists = await this.prisma.profile.findUnique({
      where: { userId },
      select: { userId: true },
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

    return this.prisma.profile.update({
      where: { userId },
      data,
    });
  }
}
