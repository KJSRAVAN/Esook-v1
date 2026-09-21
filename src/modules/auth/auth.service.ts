import {
  Injectable, UnauthorizedException, HttpException, HttpStatus, Logger,
  ConflictException, NotFoundException,
} from '@nestjs/common';
import * as argon2 from 'argon2';
import { OtpService } from './otp/otp.service';
import { TokenService } from './token/token.service';
import { AuthRepository, SafeUser } from './auth.repository';
import {
  SendOtpDto, VerifyOtpDto, StaffLoginDto, RefreshTokenDto, LogoutDto, RegisterDriverDto,
  CustomerSignupDto, CustomerVerifyEmailDto, CustomerLoginDto,
  CustomerRequestPasswordResetDto, CustomerResetPasswordDto,
} from './auth.schemas';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly otp: OtpService,
    private readonly tokens: TokenService,
    private readonly repo: AuthRepository,
  ) {}

  // Customer Password + Email Verification Flow
  async customerSignup(dto: CustomerSignupDto): Promise<{ message: string; email: string }> {
    const email = dto.email.trim().toLowerCase();
    const phone = dto.phone.trim();

    const existingByEmail = await this.repo.findByEmailWithPassword(email);
    if (existingByEmail && (existingByEmail.role !== 'CUSTOMER' || existingByEmail.isEmailVerified)) {
      throw new ConflictException({ code: 'EMAIL_TAKEN', message: 'Email address is already registered' });
    }

    const existingByPhone = await this.repo.findByPhoneWithPassword(phone);
    if (existingByPhone && existingByPhone.id !== existingByEmail?.id) {
      if (existingByPhone.role !== 'CUSTOMER' || existingByPhone.isEmailVerified || existingByPhone.passwordHash) {
        throw new ConflictException({ code: 'PHONE_TAKEN', message: 'Phone number is already registered' });
      }
    }

    const passwordHash = await argon2.hash(dto.password);
    let user: SafeUser;

    if (existingByEmail && existingByEmail.role === 'CUSTOMER' && !existingByEmail.isEmailVerified) {
      user = await this.repo.updateCustomer(existingByEmail.id, { name: dto.name.trim(), phone, passwordHash, isEmailVerified: true });
    } else if (existingByPhone && existingByPhone.role === 'CUSTOMER' && !existingByPhone.passwordHash) {
      user = await this.repo.updateCustomer(existingByPhone.id, {
        name: dto.name.trim(), email, passwordHash, isEmailVerified: true,
      });
    } else {
      user = await this.repo.createCustomer({ name: dto.name.trim(), email, phone, passwordHash });
    }

    try {
      await this.otp.sendEmailOtp(email, 'verification');
    } catch {
      // Best-effort email dispatch during launch mode
    }

    await this.repo.writeAuditLog({
      entity: 'user', entityId: user.id, action: 'customer_registered',
      metadata: { email: email.slice(0, 3) + '***', phonePrefix: phone.slice(0, 5) },
    });
    this.logger.log(`Customer registered (active & email verified): ${user.id}`);
    return { message: 'Account created successfully. You can now log in.', email };
  }

  async customerVerifyEmail(dto: CustomerVerifyEmailDto): Promise<{
    accessToken: string; refreshToken: string; user: object; message: string;
  }> {
    const email = dto.email.trim().toLowerCase();
    await this.otp.verifyEmailOtp(email, dto.code, 'verification');

    const user = await this.repo.findByEmail(email);
    if (!user || user.role !== 'CUSTOMER') {
      throw new NotFoundException({ code: 'USER_NOT_FOUND', message: 'Customer account not found' });
    }

    const verifiedUser = await this.repo.markEmailVerified(user.id);
    const { accessToken, refreshToken } = await this.tokens.issueTokenPair(
      verifiedUser.id, verifiedUser.role, verifiedUser.storeId,
    );

    await this.repo.writeAuditLog({
      entity: 'user', entityId: verifiedUser.id, action: 'customer_email_verified', actorId: verifiedUser.id,
    });
    this.logger.log(`Customer email verified: ${verifiedUser.id}`);
    return { accessToken, refreshToken, user: verifiedUser, message: 'Email verified successfully' };
  }

  async customerLogin(dto: CustomerLoginDto): Promise<{
    accessToken: string;
    refreshToken: string;
    user: object;
  }> {
    const email = dto.email?.trim().toLowerCase();
    const phone = dto.phone?.trim();

    const user = email
      ? await this.repo.findByEmailWithPassword(email)
      : await this.repo.findByPhoneWithPassword(phone!);

    if (!user || !user.passwordHash || user.role !== 'CUSTOMER') {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (!user.isActive) {
      throw new HttpException(
        { code: 'ACCOUNT_INACTIVE', message: 'Account is deactivated' },
        HttpStatus.FORBIDDEN,
      );
    }

    const valid = await argon2.verify(user.passwordHash, dto.password);
    if (!valid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (!user.isEmailVerified) {
      throw new HttpException(
        {
          code: 'EMAIL_NOT_VERIFIED',
          message: 'Please verify your email address before logging in.',
        },
        HttpStatus.FORBIDDEN,
      );
    }

    const { accessToken, refreshToken } = await this.tokens.issueTokenPair(
      user.id,
      user.role,
      user.storeId,
    );

    this.logger.log(`Customer login: ${user.id}`);
    const { passwordHash: _pw, ...safeUser } = user;
    return { accessToken, refreshToken, user: safeUser };
  }

  async customerRequestPasswordReset(dto: CustomerRequestPasswordResetDto): Promise<{ message: string }> {
    const email = dto.email.trim().toLowerCase();
    const user = await this.repo.findByEmailWithPassword(email);

    // Anti-enumeration: return standard success response even if user not found
    if (!user || user.role !== 'CUSTOMER') {
      return { message: 'If an account exists with this email, a reset code has been sent.' };
    }

    await this.otp.sendEmailOtp(email, 'password_reset');
    await this.repo.writeAuditLog({
      entity: 'user',
      entityId: user.id,
      action: 'password_reset_requested',
    });

    return { message: 'If an account exists with this email, a reset code has been sent.' };
  }

  async customerResetPassword(dto: CustomerResetPasswordDto): Promise<{ message: string }> {
    const email = dto.email.trim().toLowerCase();
    await this.otp.verifyEmailOtp(email, dto.code, 'password_reset');

    const user = await this.repo.findByEmailWithPassword(email);
    if (!user || user.role !== 'CUSTOMER') {
      throw new NotFoundException({
        code: 'USER_NOT_FOUND',
        message: 'Customer account not found',
      });
    }

    const passwordHash = await argon2.hash(dto.newPassword);
    await this.repo.updatePasswordHash(user.id, passwordHash);
    await this.tokens.revokeAllUserTokens(user.id);
    await this.repo.invalidateUserCache(user.id);

    await this.repo.writeAuditLog({
      entity: 'user',
      entityId: user.id,
      action: 'password_reset_completed',
    });

    this.logger.log(`Password reset completed for customer: ${user.id}`);
    return { message: 'Password has been reset successfully. Please log in with your new password.' };
  }

  // ---------------------------------------------------------------------------
  // Customer Phone OTP flow (Legacy fallback)
  // ---------------------------------------------------------------------------

  async sendOtp(dto: SendOtpDto): Promise<{ channel: string; message: string }> {
    const { channel } = await this.otp.sendOtp(dto.phone, dto.email);
    await this.repo.writeAuditLog({
      entity: 'otp', entityId: 'N/A', action: 'otp_sent',
      metadata: { channel, phonePrefix: dto.phone.slice(0, 5) },
    });
    return { channel, message: `Verification code sent via ${channel}` };
  }

  async verifyOtp(dto: VerifyOtpDto): Promise<{
    accessToken: string; refreshToken: string; user: object; isNew: boolean;
  }> {
    await this.otp.verifyOtp(dto.phone, dto.code);
    const user = await this.repo.upsertCustomerByPhone(dto.phone);
    const isNew = !user.isPhoneVerified;
    const { accessToken, refreshToken } = await this.tokens.issueTokenPair(
      user.id, user.role, user.storeId,
    );
    await this.repo.writeAuditLog({
      entity: 'otp', entityId: user.id, action: 'otp_verified',
      actorId: user.id, metadata: { phonePrefix: dto.phone.slice(0, 5), isNew },
    });
    this.logger.log(`Customer login via OTP: ${user.id}`);
    return { accessToken, refreshToken, user, isNew };
  }

  // ---------------------------------------------------------------------------
  // Staff / Admin password flow
  // ---------------------------------------------------------------------------

  async staffLogin(dto: StaffLoginDto): Promise<{
    accessToken: string; refreshToken: string; user: object;
  }> {
    // Accept either email OR phone — drivers use phone, staff use email
    const user = dto.email
      ? await this.repo.findByEmailWithPassword(dto.email)
      : await this.repo.findByPhoneWithPassword(dto.phone!);

    if (!user || !user.passwordHash || user.role === 'CUSTOMER') {
      throw new UnauthorizedException('Invalid credentials');
    }
    if (!user.isActive) {
      throw new HttpException(
        { code: 'ACCOUNT_INACTIVE', message: 'Account is deactivated' },
        HttpStatus.FORBIDDEN,
      );
    }

    const valid = await argon2.verify(user.passwordHash, dto.password);
    if (!valid) throw new UnauthorizedException('Invalid credentials');

    const { accessToken, refreshToken } = await this.tokens.issueTokenPair(
      user.id, user.role, user.storeId,
    );
    this.logger.log(`Staff/Driver login: ${user.id} (${user.role})`);
    const { passwordHash: _pw, ...safeUser } = user;
    return { accessToken, refreshToken, user: safeUser };
  }

  // ---------------------------------------------------------------------------
  // Driver registration (SUPER_ADMIN only)
  // ---------------------------------------------------------------------------

  async registerDriver(dto: RegisterDriverDto): Promise<object> {
    const existing = await this.repo.findByPhone(dto.phone);
    if (existing) {
      throw new ConflictException({ code: 'PHONE_TAKEN', message: 'Phone number already registered' });
    }

    const passwordHash = await argon2.hash(dto.password);
    const driver = await this.repo.createDriver({ name: dto.name, phone: dto.phone, passwordHash });

    await this.repo.writeAuditLog({
      entity: 'user', entityId: driver.id, action: 'driver_registered',
      metadata: { phone: dto.phone.slice(0, 5) + '****' },
    });

    this.logger.log(`Driver registered: ${driver.id}`);
    return driver;
  }

  // ---------------------------------------------------------------------------
  // Token management
  // ---------------------------------------------------------------------------

  async refresh(dto: RefreshTokenDto): Promise<{ accessToken: string; refreshToken: string }> {
    return this.tokens.rotateRefreshToken(dto.refreshToken);
  }

  async logout(dto: LogoutDto): Promise<void> {
    await this.tokens.revokeRefreshToken(dto.refreshToken);
    this.logger.log('User logged out (refresh token revoked)');
  }
}