import {
  Injectable,
  UnauthorizedException,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import * as argon2 from 'argon2';
import { OtpService } from './otp/otp.service';
import { TokenService } from './token/token.service';
import { AuthRepository } from './auth.repository';
import {
  SendOtpDto,
  VerifyOtpDto,
  StaffLoginDto,
  RefreshTokenDto,
  LogoutDto,
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

    // Audit log -- no phone number, no code
    await this.repo.writeAuditLog({
      entity: 'otp',
      entityId: 'N/A',
      action: 'otp_sent',
      metadata: { channel, phonePrefix: dto.phone.slice(0, 5) },
    });

    return {
      channel,
      message: `Verification code sent via ${channel}`,
    };
  }

  async verifyOtp(dto: VerifyOtpDto): Promise<{
    accessToken: string;
    refreshToken: string;
    user: object;
    isNew: boolean;
  }> {
    // Throws on invalid/expired/too-many-attempts
    await this.otp.verifyOtp(dto.phone, dto.code);

    // Upsert customer -- first-time login creates the account
    const user = await this.repo.upsertCustomerByPhone(dto.phone);
    const isNew = !user.isPhoneVerified;

    const { accessToken, refreshToken } = await this.tokens.issueTokenPair(
      user.id,
      user.role,
      user.storeId,
    );

    await this.repo.writeAuditLog({
      entity: 'otp',
      entityId: user.id,
      action: 'otp_verified',
      actorId: user.id,
      metadata: { phonePrefix: dto.phone.slice(0, 5), isNew },
    });

    this.logger.log(`Customer login via OTP: ${user.id}`);

    return { accessToken, refreshToken, user, isNew };
  }

  // ---------------------------------------------------------------------------
  // Staff / Admin password flow
  // ---------------------------------------------------------------------------

  async staffLogin(dto: StaffLoginDto): Promise<{
    accessToken: string;
    refreshToken: string;
    user: object;
  }> {
    const user = await this.repo.findByEmailWithPassword(dto.email);

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
    if (!valid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const { accessToken, refreshToken } = await this.tokens.issueTokenPair(
      user.id,
      user.role,
      user.storeId,
    );

    this.logger.log(`Staff login: ${user.id} (${user.role})`);

    const { passwordHash: _pw, ...safeUser } = user;
    return { accessToken, refreshToken, user: safeUser };
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
