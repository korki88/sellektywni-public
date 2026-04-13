import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { ProfileRole } from '@prisma/client';
import { AllPermissionValues, defaultPermissionsForRole } from '../auth/permissions';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class StaffPermissionsService {
  constructor(private readonly prisma: PrismaService) {}

  async listUsers() {
    const users = await this.prisma.profile.findMany({
      orderBy: { createdAt: 'asc' },
      select: {
        userId: true,
        email: true,
        role: true,
        permissions: true,
      },
    });
    return {
      availablePermissions: AllPermissionValues,
      users,
    };
  }

  async updatePermissions(userId: string, permissions: string[]) {
    const profile = await this.prisma.profile.findUnique({ where: { userId } });
    if (!profile) throw new NotFoundException('Profil nie istnieje');
    if (profile.role === ProfileRole.OWNER) {
      throw new BadRequestException('Uprawnień właściciela nie można ograniczyć.');
    }
    const unique = [...new Set(permissions.map((p) => p.trim()).filter(Boolean))];
    const allowed = new Set<string>(AllPermissionValues);
    const invalid = unique.filter((p) => !allowed.has(p));
    if (invalid.length > 0) {
      throw new BadRequestException(`Nieznane uprawnienia: ${invalid.join(', ')}`);
    }
    const normalized =
      unique.length > 0 ? unique : defaultPermissionsForRole(profile.role);
    return this.prisma.profile.update({
      where: { userId },
      data: { permissions: normalized },
      select: {
        userId: true,
        email: true,
        role: true,
        permissions: true,
      },
    });
  }
}
