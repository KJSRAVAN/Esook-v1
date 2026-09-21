import { Test } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { Logger } from '@nestjs/common';
import { EmailOtpProvider } from './email-otp.provider';

const mockSend = jest.fn();

jest.mock('resend', () => ({
  Resend: jest.fn().mockImplementation(() => ({
    emails: {
      send: mockSend,
    },
  })),
}));

describe('EmailOtpProvider (Resend HTTPS API)', () => {
  let provider: EmailOtpProvider;
  let configService: Partial<ConfigService>;
  let loggerLogSpy: jest.SpyInstance;
  let loggerErrorSpy: jest.SpyInstance;

  beforeEach(async () => {
    jest.clearAllMocks();
    loggerLogSpy = jest.spyOn(Logger.prototype, 'log').mockImplementation();
    loggerErrorSpy = jest.spyOn(Logger.prototype, 'error').mockImplementation();

    configService = {
      get: jest.fn((key: string, def?: unknown) => {
        const configMap: Record<string, unknown> = {
          RESEND_API_KEY: 're_test_mock_key',
          EMAIL_FROM: 'eSook Test <noreply@esook.store>',
        };
        return configMap[key] ?? def;
      }),
    };

    const module = await Test.createTestingModule({
      providers: [
        EmailOtpProvider,
        { provide: ConfigService, useValue: configService },
      ],
    }).compile();

    provider = module.get(EmailOtpProvider);
  });

  afterEach(() => {
    loggerLogSpy.mockRestore();
    loggerErrorSpy.mockRestore();
  });

  it('sends verification email through Resend with correct recipient, from, and subject', async () => {
    mockSend.mockResolvedValue({ data: { id: 'resend_msg_123' }, error: null });

    const result = await provider.sendOtp('customer@example.com', '123456', 'verification');

    expect(result.success).toBe(true);
    expect(result.channel).toBe('email');
    expect(mockSend).toHaveBeenCalledWith(
      expect.objectContaining({
        from: 'eSook Test <noreply@esook.store>',
        to: 'customer@example.com',
        subject: 'Your Esook verification code',
        text: expect.stringContaining('123456'),
        html: expect.stringContaining('123456'),
      }),
    );
  });

  it('sends password reset email through Resend with dedicated subject and instructions', async () => {
    mockSend.mockResolvedValue({ data: { id: 'resend_msg_456' }, error: null });

    const result = await provider.sendOtp('customer@example.com', '654321', 'password_reset');

    expect(result.success).toBe(true);
    expect(mockSend).toHaveBeenCalledWith(
      expect.objectContaining({
        from: 'eSook Test <noreply@esook.store>',
        to: 'customer@example.com',
        subject: 'Your Esook password reset code',
        text: expect.stringContaining('654321'),
        html: expect.stringContaining('Reset Your Password'),
      }),
    );
  });

  it('fails safely with controlled error when RESEND_API_KEY is not configured', async () => {
    const unconfiguredConfig: Partial<ConfigService> = {
      get: jest.fn().mockReturnValue(undefined),
    };

    const module = await Test.createTestingModule({
      providers: [
        EmailOtpProvider,
        { provide: ConfigService, useValue: unconfiguredConfig },
      ],
    }).compile();

    const unconfiguredProvider = module.get(EmailOtpProvider);
    const result = await unconfiguredProvider.sendOtp('customer@example.com', '123456', 'verification');

    expect(result.success).toBe(false);
    expect(result.error).toBe('Email not configured');
    expect(mockSend).not.toHaveBeenCalled();
  });

  it('returns controlled failure when Resend API returns an error response', async () => {
    mockSend.mockResolvedValue({
      data: null,
      error: { name: 'validation_error', message: 'Domain not verified' },
    });

    const result = await provider.sendOtp('customer@example.com', '123456', 'verification');

    expect(result.success).toBe(false);
    expect(result.error).toBe('Domain not verified');
  });

  it('handles unexpected network exceptions without crashing', async () => {
    mockSend.mockRejectedValue(new Error('Network connection reset'));

    const result = await provider.sendOtp('customer@example.com', '123456', 'verification');

    expect(result.success).toBe(false);
    expect(result.error).toBe('Network connection reset');
  });

  it('never leaks the raw OTP value in application logs', async () => {
    mockSend.mockResolvedValue({ data: { id: 'msg_999' }, error: null });
    const rawSecretOtp = '987654';

    await provider.sendOtp('user@example.com', rawSecretOtp, 'verification');

    // Inspect all logger invocations
    const allLogCalls = loggerLogSpy.mock.calls.map((args) => args.join(' '));
    const allErrCalls = loggerErrorSpy.mock.calls.map((args) => args.join(' '));
    const allLogs = [...allLogCalls, ...allErrCalls].join('\n');

    expect(allLogs).not.toContain(rawSecretOtp);
  });
});
