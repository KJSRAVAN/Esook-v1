import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '@shared/database/prisma.service';
import { RedisService } from '@shared/redis/redis.service';

const USER_CACHE_TTL = 120; // 2 minutes — shorter than 15min access token
const userCacheKey = (id: string) => `user:jwt:${id}`;

/**
 * JWT validation strategy.
 *
 * Performance: user is cached in Redis for 2 minutes to avoid a DB query
 * on every authenticated request. Cache miss falls back to DB and repopulates.
 *
 * Security trade-off: a deactivated account may remain active for up to 2 minutes
 * (or until the 15-minute JWT expires). This is the industry-standard trade-off
 * for stateless JWT auth. For immediate deactivation, call revokeAllUserTokens().
 */
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly redis: RedisService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('JWT_ACCESS_SECRET'),
    });
  }

  async validate(payload: { sub: string; role: string; storeId: string | null }) {
    // 1. Try Redis cache first
    try {
      const cached = await this.redis.get(userCacheKey(payload.sub));
      if (cached) return JSON.parse(cached);
    } catch {
      // Redis unavailable — fall through to DB
    }

    // 2. Cache miss — query DB
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub, isActive: true },
      select: {
        id: true, name: true, email: true, phone: true,
        role: true, storeId: true, isPhoneVerified: true, isActive: true,
      },
    });

    if (!user) return null; // Passport returns 401 automatically

    // 3. Populate cache (best-effort — don't fail if Redis is down)
    try {
      await this.redis.set(
        userCacheKey(user.id),
        JSON.stringify(user),
        'EX',
        USER_CACHE_TTL,
      );
    } catch {
      // Redis unavailable — continue without caching
    }

    return user;
  }
}