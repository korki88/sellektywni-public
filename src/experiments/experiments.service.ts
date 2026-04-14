import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

function bucketIndex(seed: string, modulo: number): number {
  let h = 0;
  for (let i = 0; i < seed.length; i++) {
    h = (h * 31 + seed.charCodeAt(i)) >>> 0;
  }
  return modulo > 0 ? h % modulo : 0;
}

@Injectable()
export class ExperimentsService {
  constructor(private readonly prisma: PrismaService) {}

  async getAssignments(userId: string) {
    const experiments = await this.prisma.experiment.findMany({
      where: { active: true },
    });
    const assignments: Array<{ key: string; variant: string }> = [];
    for (const e of experiments) {
      const key = e.key;
      let row = await this.prisma.experimentAssignment.findUnique({
        where: {
          userId_experimentKey: { userId, experimentKey: key },
        },
      });
      if (!row) {
        const raw = e.variants;
        const parsed = Array.isArray(raw)
          ? raw.filter((v): v is string => typeof v === 'string')
          : [];
        const list = parsed.length > 0 ? parsed : ['control', 'variant_b'];
        const idx = bucketIndex(`${userId}:${key}`, list.length);
        const variant = list[idx] ?? 'control';
        row = await this.prisma.experimentAssignment.create({
          data: {
            userId,
            experimentKey: key,
            variant,
          },
        });
      }
      assignments.push({ key, variant: row.variant });
    }
    return { assignments };
  }

  listAllForStaff() {
    return this.prisma.experiment.findMany({
      orderBy: { key: 'asc' },
    });
  }

  async upsertExperiment(data: {
    key: string;
    active: boolean;
    variants: string[];
  }) {
    const key = data.key
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9_-]/g, '_')
      .replace(/_+/g, '_');
    if (key.length < 2) {
      throw new BadRequestException('Nieprawidłowy klucz eksperymentu');
    }
    const rawList = data.variants ?? [];
    const variants = rawList
      .map((v) => String(v).trim())
      .filter((v) => v.length > 0);
    const list = variants.length > 0 ? variants : ['control', 'variant_b'];
    const json = list as unknown as Prisma.InputJsonValue;
    return this.prisma.experiment.upsert({
      where: { key },
      create: {
        key,
        active: data.active,
        variants: json,
      },
      update: {
        active: data.active,
        variants: json,
      },
    });
  }

  async patchExperimentActive(keyRaw: string, active: boolean) {
    const key = keyRaw.trim();
    const existing = await this.prisma.experiment.findUnique({
      where: { key },
    });
    if (!existing) {
      throw new BadRequestException('Nie znaleziono eksperymentu');
    }
    return this.prisma.experiment.update({
      where: { key },
      data: { active },
    });
  }
}
