import { Controller, Get, Post, Patch, Param, Body, UseGuards, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiBody } from '@nestjs/swagger';
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

  @ApiOperation({ summary: 'Validate a coupon code before placing an order (public)' })
  @ApiBody({
    schema: {
      type: 'object', required: ['code', 'orderTotal'],
      properties: {
        code:       { type: 'string', example: 'SAVE20' },
        orderTotal: { type: 'number', example: 150.00 },
      },
    },
  })
  @Post('validate')
  @HttpCode(HttpStatus.OK)
  validate(@Body(new ZodValidationPipe(validateCouponSchema)) body: ValidateCouponDto) {
    return this.coupons.validate(body);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'List all coupons (SUPER_ADMIN)' })
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @Get()
  getAll() {
    return this.coupons.getAll();
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get coupon by code (SUPER_ADMIN)' })
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @Get(':code')
  getByCode(@Param('code') code: string) {
    return this.coupons.getByCode(code);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Create a coupon (SUPER_ADMIN)' })
  @ApiBody({
    schema: {
      type: 'object', required: ['code', 'discountType', 'discountValue'],
      properties: {
        code:          { type: 'string', example: 'SAVE20' },
        discountType:  { type: 'string', enum: ['PERCENT', 'FLAT'], example: 'PERCENT' },
        discountValue: { type: 'number', example: 20 },
        minOrderValue: { type: 'number', example: 100 },
        maxUses:       { type: 'integer', example: 500 },
        expiresAt:     { type: 'string', format: 'date-time', example: '2026-12-31T23:59:59Z' },
      },
    },
  })
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('SUPER_ADMIN')
  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@Body(new ZodValidationPipe(createCouponSchema)) body: CreateCouponDto) {
    return this.coupons.create(body);
  }

  @ApiBearerAuth()
  @ApiOperation({ summary: 'Update a coupon (SUPER_ADMIN)' })
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        discountValue: { type: 'number', example: 25 },
        maxUses:       { type: 'integer', example: 1000 },
        isActive:      { type: 'boolean', example: false },
        expiresAt:     { type: 'string', format: 'date-time', example: '2027-06-30T23:59:59Z' },
      },
    },
  })
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