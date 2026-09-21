import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import * as argon2 from 'argon2';
import { AuthController } from '../auth.controller';
import { AuthService } from '../auth.service';
import { AuthRepository } from '../auth.repository';
import { OtpService } from '../otp/otp.service';
import { TokenService } from '../token/token.service';

describe('Customer Auth Controller Smoke Test', () => {
  let app: INestApplication;
  let mockUserDb: Map<string, any>;

  beforeAll(async () => {
    mockUserDb = new Map();

    const mockRepo = {
      findByEmailWithPassword: jest.fn().mockImplementation(async (email: string) => {
        return mockUserDb.get(email.toLowerCase()) ?? null;
      }),
      findByPhoneWithPassword: jest.fn().mockImplementation(async (phone: string) => {
        for (const user of mockUserDb.values()) {
          if (user.phone === phone) return user;
        }
        return null;
      }),
      findByEmail: jest.fn().mockImplementation(async (email: string) => {
        return mockUserDb.get(email.toLowerCase()) ?? null;
      }),
      createCustomer: jest.fn().mockImplementation(async (data: any) => {
        const user = {
          id: 'usr_smoke_test_1',
          name: data.name,
          email: data.email,
          phone: data.phone,
          passwordHash: data.passwordHash,
          role: 'CUSTOMER',
          storeId: null,
          isEmailVerified: true,
          isPhoneVerified: false,
          isActive: true,
          createdAt: new Date(),
          updatedAt: new Date(),
        };
        mockUserDb.set(data.email.toLowerCase(), user);
        return user;
      }),
      writeAuditLog: jest.fn().mockResolvedValue(undefined),
      invalidateUserCache: jest.fn().mockResolvedValue(undefined),
    };

    const mockOtp = {
      sendEmailOtp: jest.fn().mockResolvedValue({ channel: 'email' }),
      verifyEmailOtp: jest.fn().mockResolvedValue(undefined),
    };

    const mockTokens = {
      issueTokenPair: jest.fn().mockResolvedValue({
        accessToken: 'mock.access.jwt.token',
        refreshToken: 'mock-refresh-token-uuid-1234',
      }),
    };

    const moduleRef: TestingModule = await Test.createTestingModule({
      controllers: [AuthController],
      providers: [
        AuthService,
        { provide: AuthRepository, useValue: mockRepo },
        { provide: OtpService, useValue: mockOtp },
        { provide: TokenService, useValue: mockTokens },
      ],
    }).compile();

    app = moduleRef.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('Step 1 -> Signup and Step 2 -> Immediate Login without OTP verification', async () => {
    const testEmail = 'smoke.customer@example.com';
    const testPhone = '+966509998877';
    const testPassword = 'SecretPassword@123';

    // 1. Customer Signup
    const signupRes = await request(app.getHttpServer())
      .post('/auth/customer/signup')
      .send({
        name: 'Smoke Test Customer',
        email: testEmail,
        phone: testPhone,
        password: testPassword,
      });

    expect(signupRes.status).toBe(201);
    expect(signupRes.body).toHaveProperty('message');
    expect(signupRes.body.email).toBe(testEmail);

    // 2. Immediate Customer Login using Email + Password
    const loginRes = await request(app.getHttpServer())
      .post('/auth/customer/login')
      .send({
        email: testEmail,
        password: testPassword,
      });

    expect(loginRes.status).toBe(200);
    expect(loginRes.body).toHaveProperty('accessToken');
    expect(loginRes.body).toHaveProperty('refreshToken');
    expect(loginRes.body).toHaveProperty('user');
    expect(loginRes.body.user.role).toBe('CUSTOMER');
    expect(loginRes.body.user.email).toBe(testEmail);
    expect(loginRes.body.user).not.toHaveProperty('passwordHash');

    // 3. Immediate Customer Login using Phone + Password
    const loginByPhoneRes = await request(app.getHttpServer())
      .post('/auth/customer/login')
      .send({
        phone: testPhone,
        password: testPassword,
      });

    expect(loginByPhoneRes.status).toBe(200);
    expect(loginByPhoneRes.body).toHaveProperty('accessToken');
    expect(loginByPhoneRes.body.user.phone).toBe(testPhone);
  });
});
