import { Injectable } from '@nestjs/common';
import { PrismaService } from '@shared/database/prisma.service';
import { Prisma } from '@prisma/client';
import { RedisService } from '@shared/redis/redis.service';

const SAFE_USER_SELECT = {
  id: true, name: true, email: true, phone: true, role: true,
  storeId: true, isPhoneVerified: true, isActive: true,
  createdAt: true, updatedAt: true,
} satisfies Prisma.UserSelect;

export type SafeUser = Prisma.UserGetPayload<{ select: typeof SAFE_USER_SELECT }>;

// Cache key shared with jwt.strategy.ts — invalidated on deactivation / role change
const userCacheKey = (id: string) => `user:jwt:${id}`;

@Injectable()
export class AuthRepository {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  /**
   * findByPhone — returns row WITHOUT passwordHash (use findByEmailWithPassword for login)
   */
  findByPhone(phone: string) {
    return this.prisma.user.findUnique({
      where: { phone },
      select: SAFE_USER_SELECT,
    });
  }

  /**
   * findByEmail — returns row WITHOUT passwordHash.
   */
  findByEmail(email: string) {
    return this.prisma.user.findUnique({
      where: { email },
      select: SAFE_USER_SELECT,
    });
  }

  /**
   * findByEmailWithPassword — returns the full user row INCLUDING passwordHash.
   * Only call this from staffLogin where argon2 verification is needed.
   */
  findByEmailWithPassword(email: string) {
    return this.prisma.user.findUnique({ where: { email } });
  }

  findById(id: string): Promise<SafeUser | null> {
    return this.prisma.user.findUnique({ where: { id }, select: SAFE_USER_SELECT });
  }

  upsertCustomerByPhone(phone: string, name?: string): Promise<SafeUser> {
    return this.prisma.user.upsert({
      where: { phone },
      update: { isPhoneVerified: true },
      create: {
        phone,
        name: name ?? 'Customer',
        role: 'CUSTOMER',
        isPhoneVerified: true,
      },
      select: SAFE_USER_SELECT,
    });
  }

  markPhoneVerified(userId: string) {
    return this.prisma.user.update({
      where: { id: userId },
      data: { isPhoneVerified: true },
      select: SAFE_USER_SELECT,
    });
  }

  /**
   * Invalidate the JWT user cache after any mutation (deactivation, role change, store reassignment).
   * Best-effort — Redis failure does not throw.
   */
  async invalidateUserCache(userId: string): Promise<void> {
    try {
      await this.redis.del(userCacheKey(userId));
    } catch {
      // Cache invalidation is best-effort
    }
  }

  writeAuditLog(data: {
    entity: string; entityId: string; action: string;
    actorId?: string; orderId?: string; metadata?: Prisma.InputJsonValue;
  }) {
    return this.prisma.auditLog.create({
      data: {
        entity: data.entity,
        entityId: data.entityId,
        action: data.action,
        actorId: data.actorId,
        orderId: data.orderId,
        metadata: data.metadata ?? {},
      },
    });
  }
}