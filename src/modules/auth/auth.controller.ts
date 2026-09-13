import {
  Controller, Post, Body, HttpCode, HttpStatus, Get, UseGuards, Req,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiBody, ApiOkResponse } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import {
  sendOtpSchema, verifyOtpSchema, staffLoginSchema,
  refreshTokenSchema, logoutSchema, registerDriverSchema,
} from './auth.schemas';
import { ZodValidationPipe } from '@shared/pipes/zod-validation.pipe';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { RolesGuard } from './guards/roles.guard';
import { Roles } from './guards/roles.decorator';
import { Request } from 'express';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @ApiOperation({ summary: 'Request OTP via WhatsApp (falls back to email)' })
  @ApiBody({
    schema: {
      type: 'object', required: ['phone'],
      properties: {
        phone: { type: 'string', example: '+966501234567', description: 'E.164 format' },
        email: { type: 'string', example: 'customer@example.com', description: 'Required for email fallback' },
        name:  { type: 'string', example: 'Ahmed Ali' },
      },
    },
  })
  @Post('otp/send')
  @HttpCode(HttpStatus.OK)
  async sendOtp(@Body(new ZodValidationPipe(sendOtpSchema)) body: unknown) {
    return this.authService.sendOtp(body as Parameters<typeof this.authService.sendOtp>[0]);
  }

  @ApiOperation({ summary: 'Verify OTP and receive JWT tokens' })
  @ApiBody({
    schema: {
      type: 'object', required: ['phone', 'code'],
      properties: {
        phone: { type: 'string', example: '+966501234567' },
        code:  { type: 'string', example: '123456', description: '6-digit OTP' },
      },
    },
  })
  @Post('otp/verify')
  @HttpCode(HttpStatus.OK)
  async verifyOtp(@Body(new ZodValidationPipe(verifyOtpSchema)) body: unknown) {
    return this.authService.verifyOtp(body as Parameters<typeof this.authService.verifyOtp>[0]);
  }

  @ApiOperation({ summary: 'Staff / Driver login — accepts email OR phone + password' })
  @ApiBody({
    schema: {
      type: 'object', required: ['password'],
      properties: {
        email:    { type: 'string', example: 'admin@esook.store', description: 'Use for staff/admin' },
        phone:    { type: 'string', example: '+966501234567', description: 'Use for drivers' },
        password: { type: 'string', example: 'Admin@1234', minLength: 8 },
      },
    },
  })
  @Post('staff/login')
  @HttpCode(HttpStatus.OK)
  async staffLogin(@Body(new ZodValidationPipe(staffLoginSchema)) body: unknown) {
    return this.authService.staffLogin(body as Parameters<typeof this.authService.staffLogin>[0]);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Register a delivery driver (SUPER_ADMIN only)' })
  @ApiBody({
    schema: {
      type: 'object', required: ['name', 'phone', 'password'],
      properties: {
        name:     { type: 'string', example: 'Mohammed Al-Rashid' },
        phone:    { type: 'string', example: '+966501234567' },
        password: { type: 'string', example: 'SecurePass@1', minLength: 8 },
      },
    },
  })
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @Post('register/driver')
  @HttpCode(HttpStatus.CREATED)
  async registerDriver(@Body(new ZodValidationPipe(registerDriverSchema)) body: unknown) {
    return this.authService.registerDriver(
      body as Parameters<typeof this.authService.registerDriver>[0],
    );
  }

  @ApiOperation({ summary: 'Rotate refresh token — returns a new token pair' })
  @ApiBody({
    schema: {
      type: 'object', required: ['refreshToken'],
      properties: { refreshToken: { type: 'string', example: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' } },
    },
  })
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  async refresh(@Body(new ZodValidationPipe(refreshTokenSchema)) body: unknown) {
    return this.authService.refresh(body as Parameters<typeof this.authService.refresh>[0]);
  }

  @ApiOperation({ summary: 'Logout — revokes the supplied refresh token' })
  @ApiBody({
    schema: {
      type: 'object', required: ['refreshToken'],
      properties: { refreshToken: { type: 'string', example: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' } },
    },
  })
  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  async logout(@Body(new ZodValidationPipe(logoutSchema)) body: unknown) {
    await this.authService.logout(body as Parameters<typeof this.authService.logout>[0]);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get current authenticated user profile' })
  @ApiOkResponse({ description: 'Returns the user object from the JWT session' })
  @UseGuards(JwtAuthGuard)
  @Get('me')
  async me(@Req() req: Request & { user: Record<string, unknown> }) {
    return req.user;
  }
}