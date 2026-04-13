import { Controller, Get, Param, Query } from '@nestjs/common';
import { ProductService } from './product.service';

@Controller('products')
export class ProductController {
  constructor(private readonly products: ProductService) {}

  @Get()
  listOffer(@Query('q') q?: string) {
    return this.products.listOffer({ search: q });
  }

  @Get(':productId/reviews')
  listReviews(@Param('productId') productId: string) {
    return this.products.listPublicReviews(productId);
  }
}
