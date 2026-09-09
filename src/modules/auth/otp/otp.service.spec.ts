import { Test } from '@nestjs/testing';
import { OtpService } from './otp.service';
import { RedisService } from '@shared/redis/redis.service';
import { WhatsAppOtpProvider } from './whatsapp-otp.provider';
import { EmailOtpProvider } from './email-otp.provider';
import { ConfigService } from '@nestjs/config';

describe('OtpService', () => {
  let service: OtpService;
  let redis: jest.Mocked<Pick<RedisService, 'get' | 'set' | 'del' | 'incr' | 'expire'>>;
  let whatsapp: jest.Mocked<Pick<WhatsAppOtpProvider, 'sendOtp'>>;
  let emailProv: jest.Mocked<Pick<EmailOtpProvider, 'sendOtp'>>;

  beforeEach(async () => {
    redis = { get: jest.fn(), set: jest.fn(), del: jest.fn(), incr: jest.fn(), expire: jest.fn() };
    whatsapp = { sendOtp: jest.fn() };
    emailProv = { sendOtp: jest.fn() };

    const module = await Test.createTestingModule({
      providers: [
        OtpService,
        { provide: RedisService, useValue: redis },
        { provide: WhatsAppOtpProvider, useValue: whatsapp },
        { provide: EmailOtpProvider, useValue: emailProv },
        {
          provide: ConfigService,
          useValue: {
            get: (key: string, def?: unknown) => {
              const m: Record<string, unknown> = {
                OTP_EXPIRY_SECONDS: 300,
                OTP_MAX_ATTEMPTS: 5,
                OTP_RATE_LIMIT_MAX: 3,
                OTP_RATE_LIMIT_WINDOW_SECONDS: 600,
              };
              return m[key] ?? def;
            },
          },
        },
      ],
    }).compile();

    service = module.get(OtpService);
  });

  describe('sendOtp', () => {
    it('sends via WhatsApp when it succeeds', async () => {
      redis.incr.mockResolvedValue(1);
      redis.expire.mockResolvedValue(1);
      redis.set.mockResolvedValue('OK');
      redis.del.mockResolvedValue(1);
      whatsapp.sendOtp.mockResolvedValue({ success: true, channel: 'whatsapp' });

      const result = await service.sendOtp('+966501234567');
      expect(result.channel).toBe('whatsapp');
    });

    it('falls back to email when WhatsApp fails', async () => {
      redis.incr.mockResolvedValue(1);
      redis.expire.mockResolvedValue(1);
      redis.set.mockResolvedValue('OK');
      redis.del.mockResolvedValue(1);
      whatsapp.sendOtp.mockResolvedValue({ success: false, channel: 'whatsapp', error: 'timeout' });
      emailProv.sendOtp.mockResolvedValue({ success: true, channel: 'email' });

      const result = await service.sendOtp('+966501234567', 'user@example.com');
      expect(result.channel).toBe('email');
    });

    it('throws OTP_RATE_LIMIT after max requests exceeded', async () => {
      redis.incr.mockResolvedValue(4); // > rateLimitMax of 3
      await expect(service.sendOtp('+966501234567')).rejects.toMatchObject({
        response: { code: 'OTP_RATE_LIMIT' },
      });
    });
  });

  describe('verifyOtp', () => {
    it('throws OTP_EXPIRED when Redis has no record', async () => {
      redis.get.mockResolvedValue(null);
      await expect(service.verifyOtp('+966501234567', '123456')).rejects.toMatchObject({
        response: { code: 'OTP_EXPIRED' },
      });
    });
  });
});
