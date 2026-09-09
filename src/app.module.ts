import { Module, MiddlewareConsumer } from '@nestjs/common';
import { ThrottlerModule } from '@nestjs/throttler';
import { ThrottlerStorageRedisService } from 'nestjs-throttler-storage-redis';
import { AppConfigModule } from '@shared/config/config.module';
import { DatabaseModule } from '@shared/database/database.module';
import { RedisModule } from '@shared/redis/redis.module';
import { RedisService } from '@shared/redis/redis.service';
import { RequestIdMiddleware } from '@shared/middleware/request-id.middleware';

import { HealthModule } from '@modules/health/health.module';
import { AuthModule } from '@modules/auth/auth.module';
import { StoresModule } from '@modules/stores/stores.module';
import { CatalogModule } from '@modules/catalog/catalog.module';
import { CartModule } from '@modules/cart/cart.module';
import { OrdersModule } from '@modules/orders/orders.module';
import { CouponsModule } from '@modules/coupons/coupons.module';
import { UsersModule } from '@modules/users/users.module';

@Module({
  imports: [
    AppConfigModule,
    DatabaseModule,
    RedisModule,
    // Global rate limiting backed by Redis — survives restarts and works across replicas.
    // Individual sensitive endpoints (OTP) have their own stricter Redis rate limits in OtpService.
    ThrottlerModule.forRootAsync({
      inject: [RedisService],
      useFactory: (redisService: RedisService) => ({
        throttlers: [{ ttl: 60_000, limit: 100 }],
        storage: new ThrottlerStorageRedisService(redisService.client),
      }),
    }),
    HealthModule,
    AuthModule,
    StoresModule,
    CatalogModule,
    CartModule,
    OrdersModule,
    CouponsModule,
    UsersModule,
  ],
})
export class AppModule {
  configure(consumer: MiddlewareConsumer): void {
    consumer.apply(RequestIdMiddleware).forRoutes('*');
  }
}

