import { Controller, Get, Param, Query } from '@nestjs/common';
import { ProductService } from './product.service';

@Controller('products')
export class ProductController {
  constructor(private readonly products: ProductService) {}

  @Get()
  listOffer(@Query('q') q?: string, @Query('featured') featured?: string) {
    const featuredOnly =
      featured === '1' ||
      featured === 'true' ||
      featured?.toLowerCase() === 'yes';
    return this.products.listOffer({ search: q, featuredOnly });
  }

  @Get(':productId/reviews')
  listReviews(@Param('productId') productId: string) {
    return this.products.listPublicReviews(productId);
  }
}
