import { Test } from '@nestjs/testing';
import { ConflictException, UnauthorizedException, NotFoundException, HttpException } from '@nestjs/common';
import * as argon2 from 'argon2';
import { AuthService } from '../auth.service';
import { AuthRepository } from '../auth.repository';
import { OtpService } from '../otp/otp.service';
import { TokenService } from '../token/token.service';

describe('Customer AuthService Suite', () => {
  let authService: AuthService;
  let repo: Record<string, jest.Mock>;
  let otp: Record<string, jest.Mock>;
  let tokens: Record<string, jest.Mock>;

  const mockCustomerUser = {
    id: 'user_cust_123', email: 'customer@example.com', phone: '+966501234567',
    name: 'Ahmed Ali', role: 'CUSTOMER', storeId: null, isActive: true,
    isPhoneVerified: true, isEmailVerified: true, createdAt: new Date(), updatedAt: new Date(),
  };

  beforeEach(async () => {
    repo = {
      findByEmailWithPassword: jest.fn(), findByPhoneWithPassword: jest.fn(),
      findByEmail: jest.fn(), findByPhone: jest.fn(),
      createCustomer: jest.fn(), updateCustomer: jest.fn(),
      markEmailVerified: jest.fn(), updatePasswordHash: jest.fn(),
      invalidateUserCache: jest.fn().mockResolvedValue(undefined),
      writeAuditLog: jest.fn().mockResolvedValue(undefined),
    };
    otp = {
      sendEmailOtp: jest.fn().mockResolvedValue({ channel: 'email' }),
      verifyEmailOtp: jest.fn().mockResolvedValue(undefined),
    };
    tokens = {
      issueTokenPair: jest.fn().mockResolvedValue({ accessToken: 'mock.access.token', refreshToken: 'mock-refresh-token-uuid' }),
      revokeAllUserTokens: jest.fn().mockResolvedValue(undefined),
    };

    const module = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: AuthRepository, useValue: repo },
        { provide: OtpService, useValue: otp },
        { provide: TokenService, useValue: tokens },
      ],
    }).compile();

    authService = module.get(AuthService);
  });

  describe('Registration & Signup', () => {
    it('creates a new customer with hashed password and sends email OTP', async () => {
      repo.findByEmailWithPassword!.mockResolvedValue(null);
      repo.findByPhoneWithPassword!.mockResolvedValue(null);
      repo.createCustomer!.mockResolvedValue({
        ...mockCustomerUser,
        isEmailVerified: false,
      });

      const result = await authService.customerSignup({
        name: 'Ahmed Ali', email: 'customer@example.com', phone: '+966501234567', password: 'Password@123',
      });
      expect(result.email).toBe('customer@example.com');
      expect(result).not.toHaveProperty('passwordHash');
      expect(otp.sendEmailOtp).toHaveBeenCalledWith('customer@example.com', 'verification');
      expect(repo.createCustomer).toHaveBeenCalledWith(
        expect.objectContaining({
          name: 'Ahmed Ali', email: 'customer@example.com', phone: '+966501234567',
          passwordHash: expect.stringMatching(/^\$argon2id\$/),
        }),
      );
    });

    it('supports international E.164 phone numbers (e.g. India +91)', async () => {
      repo.findByEmailWithPassword!.mockResolvedValue(null);
      repo.findByPhoneWithPassword!.mockResolvedValue(null);
      repo.createCustomer!.mockResolvedValue({ ...mockCustomerUser, phone: '+919876543210', isEmailVerified: false });

      await authService.customerSignup({
        name: 'Raj Sharma', email: 'raj@example.com', phone: '+919876543210', password: 'Password@123',
      });
      expect(repo.createCustomer).toHaveBeenCalledWith(expect.objectContaining({ phone: '+919876543210' }));
    });

    it('rejects duplicate email for an existing verified customer', async () => {
      repo.findByEmailWithPassword!.mockResolvedValue({ ...mockCustomerUser, passwordHash: 'hash' } as any);
      await expect(
        authService.customerSignup({
          name: 'Test', email: 'customer@example.com', phone: '+966509999999', password: 'Password@123',
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('rejects signup when phone is already taken by a staff user', async () => {
      repo.findByEmailWithPassword!.mockResolvedValue(null);
      repo.findByPhoneWithPassword!.mockResolvedValue({
        ...mockCustomerUser,
        role: 'STORE_STAFF',
        passwordHash: 'hash',
      } as any);

      await expect(
        authService.customerSignup({
          name: 'Test', email: 'new@example.com', phone: '+966501234567', password: 'Password@123',
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('rejects signup when phone is already taken by another customer with a password', async () => {
      repo.findByEmailWithPassword!.mockResolvedValue(null);
      repo.findByPhoneWithPassword!.mockResolvedValue({
        ...mockCustomerUser, id: 'other_user', role: 'CUSTOMER', passwordHash: 'hashed_pw',
      } as any);

      await expect(
        authService.customerSignup({
          name: 'Test', email: 'new@example.com', phone: '+966501234567', password: 'Password@123',
        }),
      ).rejects.toThrow(ConflictException);
    });

    it('links email and password to legacy phone-only customer', async () => {
      repo.findByEmailWithPassword!.mockResolvedValue(null);
      repo.findByPhoneWithPassword!.mockResolvedValue({
        ...mockCustomerUser,
        role: 'CUSTOMER',
        email: null,
        isEmailVerified: false,
        passwordHash: null,
      } as any);
      repo.updateCustomer!.mockResolvedValue({
        ...mockCustomerUser,
        isEmailVerified: false,
      });

      await authService.customerSignup({
        name: 'Ahmed Ali',
        email: 'customer@example.com',
        phone: '+966501234567',
        password: 'Password@123',
      });

      expect(repo.updateCustomer).toHaveBeenCalledWith(
        mockCustomerUser.id,
        expect.objectContaining({ email: 'customer@example.com' }),
      );
      expect(otp.sendEmailOtp).toHaveBeenCalledWith('customer@example.com', 'verification');
    });
  });

  describe('Email Verification', () => {
    it('verifies customer email and returns tokens', async () => {
      repo.findByEmail!.mockResolvedValue(mockCustomerUser as any);
      repo.markEmailVerified!.mockResolvedValue({
        ...mockCustomerUser,
        isEmailVerified: true,
      });

      const res = await authService.customerVerifyEmail({
        email: 'customer@example.com',
        code: '123456',
      });

      expect(otp.verifyEmailOtp).toHaveBeenCalledWith('customer@example.com', '123456', 'verification');
      expect(repo.markEmailVerified).toHaveBeenCalledWith(mockCustomerUser.id);
      expect(res.accessToken).toBe('mock.access.token');
      expect(res.refreshToken).toBe('mock-refresh-token-uuid');
      expect(res).not.toHaveProperty('code');
    });

    it('rejects verification if user is not found or not CUSTOMER', async () => {
      repo.findByEmail!.mockResolvedValue({
        ...mockCustomerUser,
        role: 'STORE_STAFF',
      } as any);

      await expect(
        authService.customerVerifyEmail({ email: 'staff@example.com', code: '123456' }),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('Customer Login', () => {
    let hashedPassword: string;

    beforeAll(async () => {
      hashedPassword = await argon2.hash('Customer@1234');
    });

    it('allows login with verified email + password', async () => {
      repo.findByEmailWithPassword!.mockResolvedValue({
        ...mockCustomerUser,
        passwordHash: hashedPassword,
        isEmailVerified: true,
      } as any);

      const res = await authService.customerLogin({
        email: 'customer@example.com',
        password: 'Customer@1234',
      });

      expect(res.accessToken).toBe('mock.access.token');
      expect((res.user as any).passwordHash).toBeUndefined();
    });

    it('allows login with verified phone + password', async () => {
      repo.findByPhoneWithPassword!.mockResolvedValue({
        ...mockCustomerUser,
        passwordHash: hashedPassword,
        isEmailVerified: true,
      } as any);

      const res = await authService.customerLogin({
        phone: '+966501234567',
        password: 'Customer@1234',
      });

      expect(res.accessToken).toBe('mock.access.token');
    });

    it('rejects customer with wrong password', async () => {
      repo.findByEmailWithPassword!.mockResolvedValue({
        ...mockCustomerUser,
        passwordHash: hashedPassword,
        isEmailVerified: true,
      } as any);

      await expect(
        authService.customerLogin({
          email: 'customer@example.com',
          password: 'WrongPassword@123',
        }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('rejects login when email is not verified', async () => {
      repo.findByEmailWithPassword!.mockResolvedValue({
        ...mockCustomerUser,
        passwordHash: hashedPassword,
        isEmailVerified: false,
      } as any);

      await expect(
        authService.customerLogin({
          email: 'customer@example.com',
          password: 'Customer@1234',
        }),
      ).rejects.toThrow(HttpException);
    });

    it('rejects staff login endpoint for CUSTOMER role', async () => {
      repo.findByEmailWithPassword!.mockResolvedValue({
        ...mockCustomerUser,
        role: 'CUSTOMER',
        passwordHash: hashedPassword,
      } as any);

      await expect(
        authService.staffLogin({
          email: 'customer@example.com',
          password: 'Customer@1234',
        }),
      ).rejects.toThrow(UnauthorizedException);
    });

    it('allows newly signed up customer to log in immediately without OTP verification', async () => {
      let createdUser: any = null;
      repo.findByEmailWithPassword!.mockResolvedValue(null);
      repo.findByPhoneWithPassword!.mockResolvedValue(null);
      repo.createCustomer!.mockImplementation(async (data: any) => {
        createdUser = {
          ...mockCustomerUser,
          id: 'user_cust_new',
          name: data.name,
          email: data.email,
          phone: data.phone,
          passwordHash: data.passwordHash,
          isEmailVerified: true,
        };
        return createdUser;
      });

      // Step 1: Customer Signup
      const signupRes = await authService.customerSignup({
        name: 'Fatima Al-Zahrani',
        email: 'fatima@example.com',
        phone: '+966509876543',
        password: 'Password@123',
      });
      expect(signupRes.email).toBe('fatima@example.com');
      expect(repo.createCustomer).toHaveBeenCalledWith(
        expect.objectContaining({
          email: 'fatima@example.com',
          phone: '+966509876543',
        }),
      );

      // Step 2: Immediate Login without prior verifyEmail step
      repo.findByEmailWithPassword!.mockResolvedValue(createdUser);
      const loginRes = await authService.customerLogin({
        email: 'fatima@example.com',
        password: 'Password@123',
      });

      expect(loginRes.accessToken).toBe('mock.access.token');
      expect(loginRes.refreshToken).toBe('mock-refresh-token-uuid');
      expect((loginRes.user as any).role).toBe('CUSTOMER');
    });
  });

  describe('Password Recovery', () => {
    it('dispatches reset OTP for existing customer', async () => {
      repo.findByEmailWithPassword!.mockResolvedValue(mockCustomerUser as any);

      const res = await authService.customerRequestPasswordReset({
        email: 'customer@example.com',
      });

      expect(otp.sendEmailOtp).toHaveBeenCalledWith('customer@example.com', 'password_reset');
      expect(res.message).toContain('If an account exists');
    });

    it('protects against email enumeration when user does not exist', async () => {
      repo.findByEmailWithPassword!.mockResolvedValue(null);

      const res = await authService.customerRequestPasswordReset({
        email: 'unknown@example.com',
      });

      expect(otp.sendEmailOtp).not.toHaveBeenCalled();
      expect(res.message).toContain('If an account exists');
    });

    it('successfully resets password, hashes with Argon2, and revokes tokens', async () => {
      repo.findByEmailWithPassword!.mockResolvedValue(mockCustomerUser as any);
      repo.updatePasswordHash!.mockResolvedValue(undefined);

      const res = await authService.customerResetPassword({
        email: 'customer@example.com', code: '123456', newPassword: 'NewPassword@123',
      });

      expect(otp.verifyEmailOtp).toHaveBeenCalledWith('customer@example.com', '123456', 'password_reset');
      expect(repo.updatePasswordHash).toHaveBeenCalledWith(
        mockCustomerUser.id,
        expect.stringMatching(/^\$argon2id\$/),
      );
      expect(tokens.revokeAllUserTokens).toHaveBeenCalledWith(mockCustomerUser.id);
      expect(res.message).toContain('reset successfully');
    });
  });
});
