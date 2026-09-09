import { Controller, Get, HttpCode, HttpStatus } from '@nestjs/common';
import { PrismaService } from '@shared/database/prisma.service';
import { RedisService } from '@shared/redis/redis.service';
import { ApiTags, ApiOperation } from '@nestjs/swagger';

/**
 * Health endpoints:
 *
 * GET /health      — Shallow. Returns immediately with no DB/Redis I/O.
 *                    Used by Railway for container health checks (polls every 30s).
 *                    Never causes DB connection usage.
 *
 * GET /health/deep — Deep. Checks DB and Redis connectivity.
 *                    Use for monitoring dashboards and post-deploy verification.
 *                    Do NOT point Railway's health check at this endpoint.
 */
@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  @ApiOperation({ summary: 'Shallow health check — no I/O (use this for Railway)' })
  @Get()
  @HttpCode(HttpStatus.OK)
  check() {
    return { status: 'ok', timestamp: new Date().toISOString() };
  }

  @ApiOperation({ summary: 'Deep health check — verifies DB and Redis connectivity' })
  @Get('deep')
  async deepCheck() {
    const [dbResult, redisResult] = await Promise.allSettled([
      this.prisma.$queryRaw`SELECT 1`,
      this.redis.healthCheck(),
    ]);

    const database = dbResult.status === 'fulfilled' ? 'up' : 'down';
    const redis =
      redisResult.status === 'fulfilled' && redisResult.value === true ? 'up' : 'down';

    const status = database === 'up' && redis === 'up' ? 'ok' : 'degraded';

    return {
      status,
      timestamp: new Date().toISOString(),
      services: { api: 'up', database, redis },
    };
  }
}