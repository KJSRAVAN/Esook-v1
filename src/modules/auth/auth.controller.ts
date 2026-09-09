import { Controller, Post, Body, HttpCode, HttpStatus, Get, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import {
  sendOtpSchema,
  verifyOtpSchema,
  staffLoginSchema,
  refreshTokenSchema,
  logoutSchema,
} from './auth.schemas';
import { ZodValidationPipe } from '@shared/pipes/zod-validation.pipe';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { Request } from 'express';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  // ------------------------------------------------------------------
  // Customer OTP flow
  // ------------------------------------------------------------------

  @ApiOperation({ summary: 'Request OTP (customer)' })
  @Post('otp/send')
  @HttpCode(HttpStatus.OK)
  async sendOtp(@Body(new ZodValidationPipe(sendOtpSchema)) body: unknown) {
    return this.authService.sendOtp(body as Parameters<typeof this.authService.sendOtp>[0]);
  }

  @ApiOperation({ summary: 'Verify OTP and receive tokens (customer)' })
  @Post('otp/verify')
  @HttpCode(HttpStatus.OK)
  async verifyOtp(@Body(new ZodValidationPipe(verifyOtpSchema)) body: unknown) {
    return this.authService.verifyOtp(body as Parameters<typeof this.authService.verifyOtp>[0]);
  }

  // ------------------------------------------------------------------
  // Staff / Admin password flow
  // ------------------------------------------------------------------

  @ApiOperation({ summary: 'Staff / Admin email + password login' })
  @Post('staff/login')
  @HttpCode(HttpStatus.OK)
  async staffLogin(@Body(new ZodValidationPipe(staffLoginSchema)) body: unknown) {
    return this.authService.staffLogin(body as Parameters<typeof this.authService.staffLogin>[0]);
  }

  // ------------------------------------------------------------------
  // Token management
  // ------------------------------------------------------------------

  @ApiOperation({ summary: 'Rotate refresh token' })
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  async refresh(@Body(new ZodValidationPipe(refreshTokenSchema)) body: unknown) {
    return this.authService.refresh(body as Parameters<typeof this.authService.refresh>[0]);
  }

  @ApiOperation({ summary: 'Logout (revoke refresh token)' })
  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  async logout(@Body(new ZodValidationPipe(logoutSchema)) body: unknown) {
    await this.authService.logout(body as Parameters<typeof this.authService.logout>[0]);
  }

  // ------------------------------------------------------------------
  // Me
  // ------------------------------------------------------------------

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get current user profile' })
  @UseGuards(JwtAuthGuard)
  @Get('me')
  async me(@Req() req: Request & { user: Record<string, unknown> }) {
    return req.user;
  }
}
