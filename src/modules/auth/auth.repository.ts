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

const userCacheKey = (id: string) => `user:jwt:${id}`;

@Injectable()
export class AuthRepository {
  constructor(
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {}

  findByPhone(phone: string) {
    return this.prisma.user.findUnique({ where: { phone }, select: SAFE_USER_SELECT });
  }

  findByEmail(email: string) {
    return this.prisma.user.findUnique({ where: { email }, select: SAFE_USER_SELECT });
  }

  /** Returns full row including passwordHash — only for login flows that need argon2 verify */
  findByEmailWithPassword(email: string) {
    return this.prisma.user.findUnique({ where: { email } });
  }

  /** Returns full row including passwordHash — driver/staff login via phone */
  findByPhoneWithPassword(phone: string) {
    return this.prisma.user.findUnique({ where: { phone } });
  }

  findById(id: string): Promise<SafeUser | null> {
    return this.prisma.user.findUnique({ where: { id }, select: SAFE_USER_SELECT });
  }

  upsertCustomerByPhone(phone: string, name?: string): Promise<SafeUser> {
    return this.prisma.user.upsert({
      where: { phone },
      update: { isPhoneVerified: true },
      create: { phone, name: name ?? 'Customer', role: 'CUSTOMER', isPhoneVerified: true },
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

  createDriver(data: { name: string; phone: string; passwordHash: string }): Promise<SafeUser> {
    return this.prisma.user.create({
      data: { ...data, role: 'DRIVER', isPhoneVerified: true },
      select: SAFE_USER_SELECT,
    });
  }

  async invalidateUserCache(userId: string): Promise<void> {
    try { await this.redis.del(userCacheKey(userId)); } catch { /* best-effort */ }
  }

  writeAuditLog(data: {
    entity: string; entityId: string; action: string;
    actorId?: string; orderId?: string; metadata?: Prisma.InputJsonValue;
  }) {
    return this.prisma.auditLog.create({
      data: {
        entity: data.entity, entityId: data.entityId, action: data.action,
        actorId: data.actorId, orderId: data.orderId, metadata: data.metadata ?? {},
      },
    });
  }
}