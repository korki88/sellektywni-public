import { Global, Module } from '@nestjs/common';
import { FeatureFlagsService } from './feature-flags.service';
import { MarketService } from './market/market.service';
import { ShopConfigController } from './shop-config.controller';

@Global()
@Module({
  controllers: [ShopConfigController],
  providers: [FeatureFlagsService, MarketService],
  exports: [FeatureFlagsService, MarketService],
})
export class CoreModule {}
