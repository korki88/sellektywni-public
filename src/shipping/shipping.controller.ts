import { Controller, Get, Query } from '@nestjs/common';
import { ShippingService } from './shipping.service';

@Controller('shipping')
export class ShippingController {
  constructor(private readonly shipping: ShippingService) {}

  @Get('providers')
  providers() {
    return this.shipping.listProviders();
  }

  @Get('points/inpost')
  async inpostPoints(
    @Query('postalCode') postalCode?: string,
    @Query('city') city?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('limit') limit?: string,
  ) {
    return this.shipping.findInpostPoints({
      postalCode: postalCode?.trim(),
      city: city?.trim(),
      lat: lat ? Number(lat) : undefined,
      lng: lng ? Number(lng) : undefined,
      limit: limit ? Number(limit) : undefined,
    });
  }

  @Get('points/dpd')
  async dpdPoints(
    @Query('postalCode') postalCode?: string,
    @Query('city') city?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('limit') limit?: string,
  ) {
    return this.shipping.findDpdPoints({
      postalCode: postalCode?.trim(),
      city: city?.trim(),
      lat: lat ? Number(lat) : undefined,
      lng: lng ? Number(lng) : undefined,
      limit: limit ? Number(limit) : undefined,
    });
  }

  @Get('points/dhl')
  async dhlPoints(
    @Query('postalCode') postalCode?: string,
    @Query('city') city?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('limit') limit?: string,
  ) {
    return this.shipping.findDhlPoints({
      postalCode: postalCode?.trim(),
      city: city?.trim(),
      lat: lat ? Number(lat) : undefined,
      lng: lng ? Number(lng) : undefined,
      limit: limit ? Number(limit) : undefined,
    });
  }

  @Get('points/poczta')
  async pocztaPoints(
    @Query('postalCode') postalCode?: string,
    @Query('city') city?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('limit') limit?: string,
  ) {
    return this.shipping.findPocztaPoints({
      postalCode: postalCode?.trim(),
      city: city?.trim(),
      lat: lat ? Number(lat) : undefined,
      lng: lng ? Number(lng) : undefined,
      limit: limit ? Number(limit) : undefined,
    });
  }

  @Get('points/orlen')
  async orlenPoints(
    @Query('postalCode') postalCode?: string,
    @Query('city') city?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('limit') limit?: string,
  ) {
    return this.shipping.findOrlenPoints({
      postalCode: postalCode?.trim(),
      city: city?.trim(),
      lat: lat ? Number(lat) : undefined,
      lng: lng ? Number(lng) : undefined,
      limit: limit ? Number(limit) : undefined,
    });
  }

  @Get('points/suggest')
  async suggestPoints(
    @Query('postalCode') postalCode?: string,
    @Query('city') city?: string,
    @Query('lat') lat?: string,
    @Query('lng') lng?: string,
    @Query('limit') limit?: string,
  ) {
    return this.shipping.suggestPickupPoints({
      postalCode: postalCode?.trim(),
      city: city?.trim(),
      lat: lat ? Number(lat) : undefined,
      lng: lng ? Number(lng) : undefined,
      limit: limit ? Number(limit) : undefined,
    });
  }

  @Get('estimate')
  estimate(
    @Query('providerCode') providerCode = 'INPOST',
    @Query('shipmentType') shipmentType = 'COURIER',
    @Query('orderTotal') orderTotal = '0',
    @Query('weightKg') weightKg = '1',
  ) {
    return this.shipping.estimatePrice({
      providerCode,
      shipmentType:
        shipmentType === 'PARCEL_LOCKER' ? 'PARCEL_LOCKER' : 'COURIER',
      orderTotal: Number(orderTotal) || 0,
      weightKg: Number(weightKg) || 1,
    });
  }
}
