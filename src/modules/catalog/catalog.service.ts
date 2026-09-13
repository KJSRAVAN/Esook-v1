import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { CatalogRepository } from './catalog.repository';
import { RedisService } from '@shared/redis/redis.service';
import {
  CreateItemDto, UpdateItemDto, CreateCategoryDto, CatalogQueryDto,
} from './catalog.schemas';

interface AuthUser { id: string; role: string; storeId: string | null; }

/**
 * Cache key convention:
 *   cache:catalog:{storeId}:items:{stableQueryHash}  — item list pages
 *   cache:catalog:{storeId}:categories               — category list
 *
 * TTL: 60s for both. On any write (create/update/delete), the entire store
 * catalog cache is invalidated using a pattern delete (SCAN+DEL).
 *
 * Cache miss behavior: falls through to DB transparently.
 * Redis failure behavior: falls through to DB transparently.
 */

const TTL = 60; // seconds

function itemsCacheKey(storeId: string, query: CatalogQueryDto): string {
  // Build a deterministic cache key from query params
  const parts = [
    `p${query.page}`,
    `l${query.limit}`,
    query.categoryId ? `c${query.categoryId}` : '',
    query.available   ? `a${query.available}` : '',
    query.search      ? `s${encodeURIComponent(query.search)}` : '',
  ].filter(Boolean).join(':');
  return `cache:catalog:${storeId}:items:${parts}`;
}

const categoriesCacheKey = (storeId: string) => `cache:catalog:${storeId}:categories`;
const storePattern       = (storeId: string) => `cache:catalog:${storeId}:*`;

@Injectable()
export class CatalogService {
  /**
   * Stampede / thundering-herd protection.
   *
   * Problem: when 50 requests arrive simultaneously for a cold cache key,
   * all 50 miss the cache and try to hit the DB at the same time, exhausting
   * the connection pool.
   *
   * Fix: track in-flight DB fetches by cache key. Any request that arrives
   * while a fetch is already running waits on the same Promise instead of
   * spawning a new DB query. Only ONE DB hit ever happens per cold key burst.
   */
  private readonly inflight = new Map<string, Promise<unknown>>();

  constructor(
    private readonly repo: CatalogRepository,
    private readonly redis: RedisService,
  ) {}

  private async withCache<T>(key: string, ttl: number, fetch: () => Promise<T>): Promise<T> {
    // 1. Try Redis cache
    try {
      const cached = await this.redis.get(key);
      if (cached) return JSON.parse(cached) as T;
    } catch { /* Redis down — fall through */ }

    // 2. If a fetch for this key is already in-flight, wait on it
    if (this.inflight.has(key)) {
      return this.inflight.get(key) as Promise<T>;
    }

    // 3. Launch exactly ONE DB fetch, store the promise, populate cache on resolve
    const promise = fetch()
      .then(async (result) => {
        try { await this.redis.set(key, JSON.stringify(result), 'EX', ttl); } catch {}
        return result;
      })
      .finally(() => this.inflight.delete(key));

    this.inflight.set(key, promise);
    return promise;
  }

  async getItems(storeId: string, query: CatalogQueryDto) {
    return this.withCache(
      itemsCacheKey(storeId, query),
      TTL,
      () => this.repo.findItems(storeId, query),
    );
  }

  async getItemById(id: string) {
    const item = await this.repo.findItemById(id);
    if (!item) throw new NotFoundException('Item not found');
    return item;
  }

  async getCategories(storeId: string) {
    return this.withCache(
      categoriesCacheKey(storeId),
      TTL,
      () => this.repo.findCategories(storeId),
    );
  }

  async createItem(storeId: string, dto: CreateItemDto, actor: AuthUser) {
    this.assertStoreAccess(actor, storeId);
    const item = await this.repo.createItem(storeId, dto);
    void this.invalidateCatalogCache(storeId);
    return item;
  }

  async updateItem(id: string, dto: UpdateItemDto, actor: AuthUser) {
    const item = await this.repo.findItemById(id);
    if (!item) throw new NotFoundException('Item not found');
    this.assertStoreAccess(actor, item.storeId);
    const updated = await this.repo.updateItem(id, dto);
    void this.invalidateCatalogCache(item.storeId);
    return updated;
  }

  async deleteItem(id: string, actor: AuthUser) {
    const item = await this.repo.findItemById(id);
    if (!item) throw new NotFoundException('Item not found');
    this.assertStoreAccess(actor, item.storeId);
    const result = await this.repo.deleteItem(id);
    void this.invalidateCatalogCache(item.storeId);
    return result;
  }

  async createCategory(storeId: string, dto: CreateCategoryDto, actor: AuthUser) {
    this.assertStoreAccess(actor, storeId);
    const category = await this.repo.createCategory(storeId, dto);
    void this.invalidateCatalogCache(storeId);
    return category;
  }

  private assertStoreAccess(actor: AuthUser, storeId: string): void {
    if (actor.role === 'SUPER_ADMIN') return;
    if (actor.storeId !== storeId)
      throw new ForbiddenException('Access to this store is not allowed');
  }

  /**
   * Invalidate all cached pages for this store's catalog using SCAN.
   * Uses pattern scan instead of KEYS to avoid blocking Redis on large keyspaces.
   * Fire-and-forget — runs after the write returns.
   */
  private async invalidateCatalogCache(storeId: string): Promise<void> {
    try {
      const pattern = storePattern(storeId);
      let cursor = '0';
      do {
        const [nextCursor, keys] = await this.redis.client.scan(cursor, 'MATCH', pattern, 'COUNT', 100);
        cursor = nextCursor;
        if (keys.length > 0) {
          await this.redis.client.del(...keys);
        }
      } while (cursor !== '0');
    } catch { /* best-effort — stale cache expires after TTL anyway */ }
  }
}