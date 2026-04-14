import { Controller, Get, Param, Query } from '@nestjs/common';
import { ProductService } from './product.service';

@Controller('products')
export class ProductController {
  constructor(private readonly products: ProductService) {}

  @Get()
  listOffer(
    @Query('q') q?: string,
    @Query('featured') featured?: string,
    @Query('offset') offsetRaw?: string,
    @Query('limit') limitRaw?: string,
  ) {
    const featuredOnly =
      featured === '1' ||
      featured === 'true' ||
      featured?.toLowerCase() === 'yes';
    const offset = Number.isFinite(Number(offsetRaw))
      ? Math.max(0, Number(offsetRaw))
      : undefined;
    const limit = Number.isFinite(Number(limitRaw))
      ? Math.min(100, Math.max(1, Number(limitRaw)))
      : undefined;
    return this.products.listOffer({ search: q, featuredOnly, offset, limit });
  }

  @Get(':productId/reviews')
  listReviews(@Param('productId') productId: string) {
    return this.products.listPublicReviews(productId);
  }
}
