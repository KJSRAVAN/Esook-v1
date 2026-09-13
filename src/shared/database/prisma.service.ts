import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { PrismaClient, Prisma } from '@prisma/client';

/**
 * Singleton Prisma client — one instance shared across the entire application.
 *
 * Connection pool strategy:
 * - PgBouncer (Supabase) runs in TRANSACTION mode, meaning a server-side
 *   connection is borrowed for the duration of a single transaction/query
 *   and immediately returned to the pool afterward.
 * - We do NOT hold persistent connections per request. Prisma reuses
 *   connections from the pool. No new pool is created per request.
 *
 * Pool sizing:
 * - connection_limit in DATABASE_URL is the TOTAL number of connections
 *   Prisma is allowed to open to PgBouncer simultaneously.
 * - Supabase free tier: 15 server-side connections total (shared).
 *   We cap Prisma at 5 so other tools (migrations, Prisma Studio, etc.)
 *   can still connect.
 * - pool_timeout=15: if all 5 connections are busy, wait up to 15s
 *   before throwing a P2024 (pool timeout) error. This prevents the
 *   30s global timeout from triggering silently.
 *
 * Dev vs production logging:
 * - Dev: only 'error' + 'warn' (not 'query') to avoid stdout I/O bottleneck
 *   adding latency to every DB call during load tests.
 */
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  constructor() {
    super({
      // Only log errors and warnings — 'query' logging in dev adds ~5-20ms
      // overhead per query due to stdout serialization and significantly
      // degrades throughput under load.
      log: [
        { emit: 'event', level: 'error' },
        { emit: 'event', level: 'warn' },
      ],
      // Datasource config here is a safety net in case DATABASE_URL
      // query params are stripped (e.g., by some hosting providers).
      // Primary pool config comes from DATABASE_URL: connection_limit + pool_timeout.
    });

    // Log slow queries (>200ms) in all environments so we catch N+1s in CI
    (this as unknown as { $on: (event: string, cb: (e: Prisma.QueryEvent) => void) => void })
      .$on?.('query', (e: Prisma.QueryEvent) => {
        if (e.duration > 200) {
          this.logger.warn(`Slow query (${e.duration}ms): ${e.query.slice(0, 120)}`);
        }
      });
  }

  async onModuleInit(): Promise<void> {
    // $connect() eagerly opens min 1 connection to validate credentials.
    // Remaining connections in the pool are opened lazily on first use.
    await this.$connect();
    this.logger.log('Database connected');
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
    this.logger.log('Database disconnected');
  }
}