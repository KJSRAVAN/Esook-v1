import { Controller, Get, Post, Patch, Param, Body, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { CouponsService } from './coupons.service';
import { createCouponSchema, updateCouponSchema, validateCouponSchema, CreateCouponDto, UpdateCouponDto, ValidateCouponDto } from './coupons.schemas';
import { ZodValidationPipe } from '@shared/pipes/zod-validation.pipe';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/guards/roles.decorator';

@ApiTags('coupons')
@Controller('coupons')
export class CouponsController {
  constructor(private readonly coupons: CouponsService) {}

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List all coupons (MANAGER+)' })
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('MANAGER', 'SUPER_ADMIN')
  @Get()
  getAll() { return this.coupons.getAll(); }

  @ApiOperation({ summary: 'Validate coupon for cart preview (public)' })
  @Post('validate')
  @HttpCode(HttpStatus.OK)
  validate(@Body(new ZodValidationPipe(validateCouponSchema)) body: ValidateCouponDto) {
    return this.coupons.validate(body);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create coupon (SUPER_ADMIN)' })
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@Body(new ZodValidationPipe(createCouponSchema)) body: CreateCouponDto) {
    return this.coupons.create(body);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update coupon (SUPER_ADMIN)' })
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @Patch(':code')
  update(
    @Param('code') code: string,
    @Body(new ZodValidationPipe(updateCouponSchema)) body: UpdateCouponDto,
  ) {
    return this.coupons.update(code, body);
  }
}
