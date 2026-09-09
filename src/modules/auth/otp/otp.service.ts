import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash, randomInt } from 'crypto';
import { RedisService } from '@shared/redis/redis.service';
import { OtpProvider } from './otp.interface';
import { WhatsAppOtpProvider } from './whatsapp-otp.provider';
import { EmailOtpProvider } from './email-otp.provider';

const OTP_HASH_KEY = (phone: string) => `otp:hash:${phone}`;
const OTP_ATTEMPTS_KEY = (phone: string) => `otp:attempts:${phone}`;
const OTP_RATE_KEY = (phone: string) => `otp:rate:${phone}`;

interface OtpRecord {
  hash: string;
  destination: string; // phone or email used for delivery
  channel: 'whatsapp' | 'email';
}

/**
 * Manages OTP lifecycle:
 *   - Generate 6-digit code
 *   - Store SHA-256 hash in Redis (never the plaintext code)
 *   - Rate limit sends (max 3 per 10 min per phone)
 *   - Enforce attempt limit (max 5 per OTP window)
 *   - Waterfall: WhatsApp -> Email
 */
@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);

  private readonly expirySeconds: number;
  private readonly maxAttempts: number;
  private readonly rateLimitMax: number;
  private readonly rateLimitWindow: number;

  constructor(
    private readonly redis: RedisService,
    private readonly whatsapp: WhatsAppOtpProvider,
    private readonly email: EmailOtpProvider,
    private readonly config: ConfigService,
  ) {
    this.expirySeconds = config.get<number>('OTP_EXPIRY_SECONDS', 300);
    this.maxAttempts = config.get<number>('OTP_MAX_ATTEMPTS', 5);
    this.rateLimitMax = config.get<number>('OTP_RATE_LIMIT_MAX', 3);
    this.rateLimitWindow = config.get<number>('OTP_RATE_LIMIT_WINDOW_SECONDS', 600);
  }

  /** Send OTP to a phone number. Tries WhatsApp first, falls back to email. */
  async sendOtp(phone: string, emailFallback?: string): Promise<{ channel: string }> {
    await this.enforceRateLimit(phone);

    const code = this.generateCode();
    const hash = this.hashCode(code);

    // Try WhatsApp first
    let result = await this.whatsapp.sendOtp(phone, code);
    let destination = phone;
    let channel: 'whatsapp' | 'email' = 'whatsapp';

    // Fallback to email if WhatsApp failed
    if (!result.success && emailFallback) {
      this.logger.warn(`WhatsApp failed for +${phone.slice(0, 4)}****, trying email fallback`);
      result = await this.email.sendOtp(emailFallback, code);
      destination = emailFallback;
      channel = 'email';
    }

    if (!result.success) {
      throw new HttpException(
        { code: 'OTP_SEND_FAILED', message: 'Failed to deliver OTP. Please try again.' },
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }

    // Store hash in Redis (not the plaintext code)
    const record: OtpRecord = { hash, destination, channel };
    try {
      await this.redis.set(
        OTP_HASH_KEY(phone),
        JSON.stringify(record),
        'EX',
        this.expirySeconds,
      );
      // Reset attempt counter
      await this.redis.del(OTP_ATTEMPTS_KEY(phone));
    } catch (err) {
      // OTP was delivered but we couldn't store the hash — tell user to retry
      const msg = err instanceof Error ? err.message : String(err);
      this.logger.error(`Redis unavailable after OTP delivery: ${msg}`);
      throw new HttpException(
        { code: 'OTP_STORE_FAILED', message: 'OTP sent but verification service is temporarily unavailable. Please try again in a moment.' },
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }

    this.logger.log(`OTP delivered via ${channel} for phone +${phone.slice(0, 4)}****`);
    return { channel };
  }

  /** Verify OTP. Returns true on success. Throws on invalid/expired/locked. */
  async verifyOtp(phone: string, code: string): Promise<void> {
    const raw = await this.redis.get(OTP_HASH_KEY(phone));

    if (!raw) {
      throw new HttpException(
        { code: 'OTP_EXPIRED', message: 'OTP expired or not found. Request a new code.' },
        HttpStatus.UNPROCESSABLE_ENTITY,
      );
    }

    const record: OtpRecord = JSON.parse(raw);

    // Check attempt count first
    const attemptsKey = OTP_ATTEMPTS_KEY(phone);
    const attempts = parseInt((await this.redis.get(attemptsKey)) ?? '0', 10);

    if (attempts >= this.maxAttempts) {
      await this.redis.del(OTP_HASH_KEY(phone));
      throw new HttpException(
        { code: 'OTP_MAX_ATTEMPTS', message: 'Too many failed attempts. Request a new code.' },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const inputHash = this.hashCode(code);
    if (inputHash !== record.hash) {
      await this.redis.set(attemptsKey, String(attempts + 1), 'KEEPTTL');
      const remaining = this.maxAttempts - (attempts + 1);
      throw new HttpException(
        {
          code: 'OTP_INVALID',
          message: `Invalid code. ${remaining} attempts remaining.`,
        },
        HttpStatus.UNPROCESSABLE_ENTITY,
      );
    }

    // Success -- clean up Redis keys
    await this.redis.del(OTP_HASH_KEY(phone));
    await this.redis.del(OTP_ATTEMPTS_KEY(phone));

    this.logger.log(`OTP verified for phone +${phone.slice(0, 4)}****`);
  }

  // ---------------------------------------------------------------------------

  private generateCode(): string {
    return String(randomInt(100_000, 999_999));
  }

  private hashCode(code: string): string {
    return createHash('sha256').update(code).digest('hex');
  }

  /**
   * Atomically enforce the OTP send rate limit.
   *
   * Pattern: SET key 1 EX window NX on first request (atomic: creates key with TTL in one command).
   * Subsequent requests use INCR — the TTL set by the first SET is preserved.
   * This avoids the TOCTOU race between INCR and EXPIRE.
   */
  private async enforceRateLimit(phone: string): Promise<void> {
    const key = OTP_RATE_KEY(phone);

    // Attempt to set the key for the first time (NX = only if not exists)
    const firstSet = await this.redis.set(key, '1', 'EX', this.rateLimitWindow, 'NX');

    let count: number;
    if (firstSet === 'OK') {
      // First request in this window
      count = 1;
    } else {
      // Key already exists — increment and check
      count = await this.redis.incr(key);
    }

    if (count > this.rateLimitMax) {
      throw new HttpException(
        {
          code: 'OTP_RATE_LIMIT',
          message: 'Too many OTP requests. Please wait before requesting another code.',
        },
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
  }
}
