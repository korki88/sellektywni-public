import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ProductService {
  constructor(private readonly prisma: PrismaService) {}

  findByIdOrDotykacka(productId?: string, idDotykacka?: string) {
    if (productId) {
      return this.prisma.product.findUnique({ where: { id: productId } });
    }
    if (idDotykacka) {
      return this.prisma.product.findUnique({ where: { idDotykacka } });
    }
    return Promise.resolve(null);
  }
}
