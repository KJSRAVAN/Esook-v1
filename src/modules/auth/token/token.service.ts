import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { createHash, randomUUID } from 'crypto';
import { PrismaService } from '@shared/database/prisma.service';
import { RefreshToken } from '@prisma/client';

export interface JwtPayload {
  sub: string;
  role: string;
  storeId: string | null;
}

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

/**
 * Handles JWT access token and rotating refresh token lifecycle.
 *
 * Refresh tokens:
 *   - Random UUID, stored SHA-256 hashed in the DB
 *   - 7-day expiry
 *   - Rotated on every use (old token revoked, new token issued)
 *   - Family revocation: if a revoked token is used, all tokens for that user are revoked
 */
@Injectable()
export class TokenService {
  private readonly logger = new Logger(TokenService.name);

  constructor(
    private readonly jwt: JwtService,
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  issueAccessToken(payload: JwtPayload): string {
    return this.jwt.sign(payload, {
      secret: this.config.get<string>('JWT_ACCESS_SECRET'),
      expiresIn: this.config.get<string>('JWT_ACCESS_EXPIRES_IN', '15m'),
    });
  }

  async issueRefreshToken(userId: string): Promise<string> {
    const token = randomUUID();
    const tokenHash = this.hashToken(token);
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1_000);

    await this.prisma.refreshToken.create({
      data: { userId, tokenHash, expiresAt },
    });

    return token;
  }

  async issueTokenPair(userId: string, role: string, storeId: string | null): Promise<TokenPair> {
    const payload: JwtPayload = { sub: userId, role, storeId };
    const accessToken = this.issueAccessToken(payload);
    const refreshToken = await this.issueRefreshToken(userId);
    return { accessToken, refreshToken };
  }

  async rotateRefreshToken(incomingToken: string): Promise<TokenPair> {
    const tokenHash = this.hashToken(incomingToken);

    const stored = await this.prisma.refreshToken.findUnique({
      where: { tokenHash },
      include: { user: true },
    });

    if (!stored) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    // Token reuse detection: if already revoked, revoke all user tokens (stolen token scenario)
    if (stored.revokedAt) {
      this.logger.warn(`Reuse of revoked refresh token detected for user ${stored.userId}`);
      await this.revokeAllUserTokens(stored.userId);
      throw new UnauthorizedException('Refresh token reuse detected. Please log in again.');
    }

    if (stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Refresh token expired');
    }

    if (!stored.user.isActive) {
      throw new UnauthorizedException('Account is deactivated');
    }

    // Revoke old token and issue new pair atomically.
    // If issueRefreshToken fails, the old token revocation is rolled back.
    const newRefreshTokenRaw = randomUUID();
    const newTokenHash = this.hashToken(newRefreshTokenRaw);
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1_000);

    await this.prisma.$transaction([
      this.prisma.refreshToken.update({
        where: { id: stored.id },
        data: { revokedAt: new Date() },
      }),
      this.prisma.refreshToken.create({
        data: { userId: stored.userId, tokenHash: newTokenHash, expiresAt },
      }),
    ]);

    const payload: JwtPayload = { sub: stored.userId, role: stored.user.role, storeId: stored.user.storeId };
    const accessToken = this.issueAccessToken(payload);

    return { accessToken, refreshToken: newRefreshTokenRaw };
  }

  async revokeRefreshToken(token: string): Promise<void> {
    const tokenHash = this.hashToken(token);
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  async revokeAllUserTokens(userId: string): Promise<void> {
    await this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  private hashToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }
}
