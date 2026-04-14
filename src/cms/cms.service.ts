import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class CmsService {
  constructor(private readonly prisma: PrismaService) {}

  listPublished() {
    return this.prisma.cmsPage.findMany({
      where: { published: true },
      select: {
        slug: true,
        title: true,
        seoDescription: true,
        updatedAt: true,
      },
      orderBy: { title: 'asc' },
    });
  }

  getPublishedBySlug(slug: string) {
    const s = slug.trim().toLowerCase();
    return this.prisma.cmsPage.findFirst({
      where: { slug: s, published: true },
    });
  }

  async getBySlugOrThrow(slug: string) {
    const row = await this.getPublishedBySlug(slug);
    if (!row) throw new NotFoundException('Strona nie istnieje');
    return row;
  }

  listAllForStaff() {
    return this.prisma.cmsPage.findMany({
      orderBy: { updatedAt: 'desc' },
    });
  }

  upsertPage(data: {
    slug: string;
    title: string;
    bodyMarkdown: string;
    published?: boolean;
    seoTitle?: string | null;
    seoDescription?: string | null;
    seoKeywords?: string | null;
  }) {
    const slug = data.slug.trim().toLowerCase();
    return this.prisma.cmsPage.upsert({
      where: { slug },
      create: {
        slug,
        title: data.title.trim(),
        bodyMarkdown: data.bodyMarkdown,
        published: data.published ?? false,
        seoTitle: data.seoTitle?.trim() || null,
        seoDescription: data.seoDescription?.trim() || null,
        seoKeywords: data.seoKeywords?.trim() || null,
      },
      update: {
        title: data.title.trim(),
        bodyMarkdown: data.bodyMarkdown,
        published: data.published ?? false,
        seoTitle: data.seoTitle?.trim() || null,
        seoDescription: data.seoDescription?.trim() || null,
        seoKeywords: data.seoKeywords?.trim() || null,
      },
    });
  }
}
