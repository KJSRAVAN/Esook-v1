import { Injectable, NotFoundException } from '@nestjs/common';
import { StoresRepository } from './stores.repository';
import { RedisService } from '@shared/redis/redis.service';
import { CreateStoreDto, UpdateStoreDto } from './stores.schemas';

const CACHE_KEYS = {
  allStores: 'cache:stores:all',
  allAreas:  'cache:stores:areas',
  store: (id: string) => `cache:stores:${id}`,
} as const;

// Stores change rarely — cache for 60 seconds.
// On write (create/update), we invalidate. Worst case: a 60s stale read.
const TTL = 60;

@Injectable()
export class StoresService {
  constructor(
    private readonly repo: StoresRepository,
    private readonly redis: RedisService,
  ) {}

  async getAll() {
    // Try cache first — eliminates DB query for the highest-traffic read endpoint
    try {
      const cached = await this.redis.get('cache:stores:all');
      if (cached) return JSON.parse(cached);
    } catch { /* Redis down — fall through to DB */ }

    const stores = await this.repo.findAll();

    try {
      await this.redis.set('cache:stores:all', JSON.stringify(stores), 'EX', TTL);
    } catch { /* best-effort */ }

    return stores;
  }

  async getById(id: string) {
    // Try cache first
    try {
      const cached = await this.redis.get(CACHE_KEYS.store(id));
      if (cached) return JSON.parse(cached);
    } catch { /* fall through */ }

    const store = await this.repo.findById(id);
    if (!store) throw new NotFoundException('Store not found');

    try {
      await this.redis.set(CACHE_KEYS.store(id), JSON.stringify(store), 'EX', TTL);
    } catch { /* best-effort */ }

    return store;
  }

  async getAreas() {
    try {
      const cached = await this.redis.get(CACHE_KEYS.allAreas);
      if (cached) return JSON.parse(cached);
    } catch { /* fall through */ }

    const areas = await this.repo.findAllAreas();

    try {
      await this.redis.set(CACHE_KEYS.allAreas, JSON.stringify(areas), 'EX', TTL);
    } catch { /* best-effort */ }

    return areas;
  }

  create(dto: CreateStoreDto) {
    // Invalidate list cache on write so next read is fresh
    void this.redis.del(CACHE_KEYS.allStores).catch(() => {});
    return this.repo.create(dto);
  }

  async update(id: string, dto: UpdateStoreDto) {
    await this.getById(id); // validates existence
    // Invalidate all related cache entries
    void Promise.allSettled([
      this.redis.del(CACHE_KEYS.allStores),
      this.redis.del(CACHE_KEYS.store(id)),
    ]);
    return this.repo.update(id, dto);
  }
}