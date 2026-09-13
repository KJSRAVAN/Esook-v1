import {
  Injectable, UnauthorizedException, HttpException, HttpStatus, Logger,
  ConflictException,
} from '@nestjs/common';
import * as argon2 from 'argon2';
import { OtpService } from './otp/otp.service';
import { TokenService } from './token/token.service';
import { AuthRepository } from './auth.repository';
import {
  SendOtpDto, VerifyOtpDto, StaffLoginDto, RefreshTokenDto, LogoutDto, RegisterDriverDto,
} from './auth.schemas';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly otp: OtpService,
    private readonly tokens: TokenService,
    private readonly repo: AuthRepository,
  ) {}

  // ---------------------------------------------------------------------------
  // Customer OTP flow
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