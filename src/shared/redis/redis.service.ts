import { Injectable, OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

/**
 * Redis service using composition (not inheritance) to avoid ioredis type conflicts.
 *
 * Resilience design:
 *  - lazyConnect: true  — app starts even if Redis is temporarily unreachable
 *  - maxRetriesPerRequest: null — ioredis retries indefinitely in background, won't
 *    throw on individual commands during a reconnect cycle
 *  - All public methods catch errors gracefully — Redis failure causes a degraded
 *    experience (e.g. empty cart, OTP unavailable), NOT an application crash
 *
 * URL resolution priority: REDIS_URL > UPSTASH_REDIS_REST_URL
 * Note: Upstash requires the ioredis-compatible URL (rediss://...), NOT the REST URL.
 */
@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  readonly client: Redis;

  constructor(config: ConfigService) {
    const url =
      config.get<string>('REDIS_URL') ||
      config.get<string>('UPSTASH_REDIS_REST_URL') ||
      'redis://localhost:6379';

    // Reject Upstash REST URLs — they start with https:// and cannot be used with ioredis.
    // Get the ioredis-compatible URL from the Upstash dashboard: Connect → ioredis tab.
    if (url.startsWith('http://') || url.startsWith('https://')) {
      throw new Error(
        `Invalid Redis URL: "${url.slice(0, 30)}..." — ioredis requires redis:// or rediss://, ` +
        `not an HTTP URL. Get the ioredis-compatible URL from the Upstash dashboard (Connect → ioredis).`,
      );
    }

    this.client = new Redis(url, {
      // Don't throw on startup if Redis is unreachable — degrade gracefully
      lazyConnect: true,
      // null = keep retrying in background; individual commands still fail fast
      maxRetriesPerRequest: null,
      // Reconnect with backoff: wait up to 2s between retries
      retryStrategy: (times: number) => Math.min(times * 200, 2000),
      enableReadyCheck: true,
      // TLS required for Upstash (rediss:// URLs handle this automatically)
      tls: url.startsWith('rediss://') ? {} : undefined,
    });

    this.client.on('error', (err: Error) => {
      // Log but don't crash — the app continues without Redis
      this.logger.error(`Redis error: ${err.message}`);
    });

    this.client.on('reconnecting', () => {
      this.logger.warn('Redis reconnecting...');
    });

    this.client.on('ready', () => {
      this.logger.log('Redis ready');
    });
  }

  async onModuleInit(): Promise<void> {
    try {
      await this.client.connect();
      this.logger.log('Redis connected');
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      // Log and continue — Redis will keep retrying in the background
      this.logger.error(`Redis initial connect failed (will retry): ${msg}`);
    }
  }

  async onModuleDestroy(): Promise<void> {
    await this.client.quit().catch(() => this.client.disconnect());
    this.logger.log('Redis disconnected');
  }

  // ---- Health check ----

  async healthCheck(): Promise<boolean> {
    try {
      const result = await this.client.ping();
      return result === 'PONG';
    } catch {
      return false;
    }
  }

  // ---- Delegated operations ----
  // These propagate errors — callers that need resilience should catch them.

  get(key: string) { return this.client.get(key); }

  set(key: string, value: string, ...args: (string | number)[]) {
    // Cast required because ioredis overloads make the return type complex,
    // but the actual return is 'OK' on success or null when NX condition not met.
    return this.client.set(key, value, ...(args as [])) as Promise<'OK' | null>;
  }

  del(...keys: string[]) { return this.client.del(...keys); }
  incr(key: string) { return this.client.incr(key); }
  expire(key: string, seconds: number) { return this.client.expire(key, seconds); }
  exists(...keys: string[]) { return this.client.exists(...keys); }
}