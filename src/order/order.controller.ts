import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Header,
  Param,
  Patch,
  Post,
  Req,
  Res,
  UnauthorizedException,
} from '@nestjs/common';
import type { Response } from 'express';
import type { Request } from 'express';
import { CreateOrderDto } from './dto/create-order.dto';
import { FinalizeOrderDto } from './dto/finalize-order.dto';
import { SubmitCartDto } from './dto/submit-cart.dto';
import { UpdateCheckoutPreferencesDto } from './dto/update-checkout-preferences.dto';
import { UpsertAddressBookEntryDto } from './dto/upsert-address-book-entry.dto';
import { ProductService } from '../product/product.service';
import { UpsertProductReviewDto } from './dto/upsert-product-review.dto';
import { CreateReturnRequestDto } from './dto/create-return-request.dto';
import { InvoicePdfService } from './invoice-pdf.service';
import { OrderService } from './order.service';

@Controller('order')
export class OrderController {
  constructor(
    private readonly orderService: OrderService,
    private readonly products: ProductService,
    private readonly invoicePdf: InvoicePdfService,
  ) {}

  private userIdFromReq(req: Request): string {
    const userId = req.supabaseJwt?.sub;
    if (!userId) {
      throw new UnauthorizedException('Brak użytkownika w sesji');
    }
    return userId;
  }

  @Post()
  placeOrder(@Body() dto: CreateOrderDto, @Req() req: Request) {
    return this.orderService.placePendingOrder(dto, this.userIdFromReq(req));
  }

  @Post('reserve')
  reserve(@Body() dto: CreateOrderDto, @Req() req: Request) {
    return this.orderService.reserveInCart(dto, this.userIdFromReq(req));
  }

  @Post('release')
  release(@Body() dto: CreateOrderDto, @Req() req: Request) {
    return this.orderService.releaseFromCart(dto, this.userIdFromReq(req));
  }

  @Post('submit-cart')
  submitCart(@Body() dto: SubmitCartDto, @Req() req: Request) {
    return this.orderService.submitCart(dto, this.userIdFromReq(req));
  }

  @Get('my-reservations')
  myReservations(@Req() req: Request) {
    return this.orderService.getReservationSummary(this.userIdFromReq(req));
  }

  @Post('finalize')
  finalize(@Body() dto: FinalizeOrderDto, @Req() req: Request) {
    return this.orderService.finalizeAcceptedOrder(
      this.userIdFromReq(req),
      dto,
    );
  }

  @Get('my-orders')
  myOrders(@Req() req: Request) {
    return this.orderService.listMyOrders(this.userIdFromReq(req));
  }

  @Get('my-orders/:orderId')
  myOrderById(@Param('orderId') orderId: string, @Req() req: Request) {
    return this.orderService.getMyOrderById(this.userIdFromReq(req), orderId);
  }

  @Post('my-orders/:orderId/cancel')
  cancelMyOrder(@Param('orderId') orderId: string, @Req() req: Request) {
    return this.orderService.cancelMyOrder(this.userIdFromReq(req), orderId);
  }

  @Get('my-orders/:orderId/invoice.pdf')
  @Header('Content-Type', 'application/pdf')
  async orderInvoicePdf(
    @Param('orderId') orderId: string,
    @Req() req: Request,
    @Res() res: Response,
  ) {
    const buf = await this.invoicePdf.buildOrderInvoicePdf(
      this.userIdFromReq(req),
      orderId,
    );
    res.setHeader(
      'Content-Disposition',
      `inline; filename="zamowienie-${orderId}.pdf"`,
    );
    res.send(buf);
  }

  @Post('my-orders/:orderId/reorder')
  reorderPayload(@Param('orderId') orderId: string, @Req() req: Request) {
    return this.orderService.getReorderPayload(
      this.userIdFromReq(req),
      orderId,
    );
  }

  @Post('returns')
  createReturn(@Body() dto: CreateReturnRequestDto, @Req() req: Request) {
    return this.orderService.createReturnRequest(this.userIdFromReq(req), dto);
  }

  @Get('my-returns')
  myReturns(@Req() req: Request) {
    return this.orderService.listMyReturns(this.userIdFromReq(req));
  }

  @Get('payments/:orderId')
  paymentForOrder(@Param('orderId') orderId: string, @Req() req: Request) {
    return this.orderService.getPaymentForOrder(
      this.userIdFromReq(req),
      orderId,
    );
  }

  @Post('payments/:orderId/simulate-success')
  simulatePaymentSuccess(
    @Param('orderId') orderId: string,
    @Req() req: Request,
  ) {
    return this.orderService.simulatePaymentSuccess(
      this.userIdFromReq(req),
      orderId,
    );
  }

  @Get('checkout/options')
  checkoutOptions(@Req() req: Request) {
    return this.orderService.getCheckoutOptions(this.userIdFromReq(req));
  }

  @Get('checkout/preferences')
  checkoutPreferences(@Req() req: Request) {
    return this.orderService.getCheckoutPreferences(this.userIdFromReq(req));
  }

  @Patch('checkout/preferences')
  updateCheckoutPreferences(
    @Body() dto: UpdateCheckoutPreferencesDto,
    @Req() req: Request,
  ) {
    return this.orderService.updateCheckoutPreferences(
      this.userIdFromReq(req),
      dto,
    );
  }

  @Get('checkout/address-book')
  addressBook(@Req() req: Request) {
    return this.orderService.listAddressBook(this.userIdFromReq(req));
  }

  @Post('checkout/address-book')
  createAddressBookEntry(
    @Body() dto: UpsertAddressBookEntryDto,
    @Req() req: Request,
  ) {
    return this.orderService.upsertAddressBookEntry(
      this.userIdFromReq(req),
      dto,
    );
  }

  @Patch('checkout/address-book/:id')
  updateAddressBookEntry(
    @Param('id') id: string,
    @Body() dto: UpsertAddressBookEntryDto,
    @Req() req: Request,
  ) {
    return this.orderService.upsertAddressBookEntry(this.userIdFromReq(req), {
      ...dto,
      id,
    });
  }

  @Delete('checkout/address-book/:id')
  deleteAddressBookEntry(@Param('id') id: string, @Req() req: Request) {
    return this.orderService.deleteAddressBookEntry(
      this.userIdFromReq(req),
      id,
    );
  }

  @Post('watch-availability')
  watchAvailability(@Body() dto: { productId?: string }, @Req() req: Request) {
    const productId = dto.productId?.trim();
    if (!productId) {
      throw new BadRequestException('Podaj productId');
    }
    return this.orderService.watchAvailability(
      this.userIdFromReq(req),
      productId,
    );
  }

  @Get('watch-availability')
  listWatchAvailability(@Req() req: Request) {
    return this.orderService.listAvailabilityWatches(this.userIdFromReq(req));
  }

  @Get('my-notifications')
  myNotifications(@Req() req: Request) {
    return this.orderService.listMyNotifications(this.userIdFromReq(req));
  }

  @Get('wishlist')
  wishlist(@Req() req: Request) {
    return this.orderService.listWishlist(this.userIdFromReq(req));
  }

  @Post('wishlist')
  addWishlist(@Body() dto: { productId?: string }, @Req() req: Request) {
    const productId = dto.productId?.trim();
    if (!productId) {
      throw new BadRequestException('Podaj productId');
    }
    return this.orderService.addWishlist(this.userIdFromReq(req), productId);
  }

  @Delete('wishlist/:productId')
  removeWishlist(@Param('productId') productId: string, @Req() req: Request) {
    return this.orderService.removeWishlist(this.userIdFromReq(req), productId);
  }

  @Post('reviews')
  upsertReview(@Body() dto: UpsertProductReviewDto, @Req() req: Request) {
    return this.products.addProductReview(
      this.userIdFromReq(req),
      dto.productId,
      dto.rating,
      dto.comment,
    );
  }
}
