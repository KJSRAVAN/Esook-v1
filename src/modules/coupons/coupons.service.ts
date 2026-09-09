import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '@shared/database/prisma.service';
import { CreateCouponDto, UpdateCouponDto, ValidateCouponDto } from './coupons.schemas';

@Injectable()
export class CouponsService {
  constructor(private readonly prisma: PrismaService) {}

  async getAll() {
    return this.prisma.coupon.findMany({ orderBy: { createdAt: 'desc' } });
  }

  async getByCode(code: string) {
    const coupon = await this.prisma.coupon.findUnique({ where: { code: code.toUpperCase() } });
    if (!coupon) throw new NotFoundException('Coupon not found');
    return coupon;
  }

  async validate(dto: ValidateCouponDto) {
    const coupon = await this.prisma.coupon.findUnique({
      where: { code: dto.code.toUpperCase() },
    });

    if (!coupon || !coupon.isActive) {
      throw new BadRequestException({ code: 'COUPON_INVALID', message: 'Invalid coupon' });
    }
    if (coupon.expiresAt && coupon.expiresAt < new Date()) {
      throw new BadRequestException({ code: 'COUPON_EXPIRED', message: 'Coupon has expired' });
    }
    if (coupon.maxUses !== null && coupon.usedCount >= coupon.maxUses) {
      throw new BadRequestException({ code: 'COUPON_EXHAUSTED', message: 'Coupon limit reached' });
    }
    if (coupon.minOrderValue && dto.orderTotal < Number(coupon.minOrderValue)) {
      throw new BadRequestException({
        code: 'COUPON_MIN_ORDER',
        message: `Minimum order value is ${coupon.minOrderValue}`,
      });
    }

    const discount =
      coupon.discountType === 'PERCENT'
        ? (dto.orderTotal * Number(coupon.discountValue)) / 100
        : Number(coupon.discountValue);

    return {
      valid: true,
      discount: Math.min(discount, dto.orderTotal),
      coupon: {
        code: coupon.code,
        discountType: coupon.discountType,
        discountValue: coupon.discountValue,
      },
    };
  }

  async create(dto: CreateCouponDto) {
    return this.prisma.coupon.create({
      data: {
        ...dto,
        expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : null,
      },
    });
  }

  async update(code: string, dto: UpdateCouponDto) {
    await this.getByCode(code);
    return this.prisma.coupon.update({
      where: { code: code.toUpperCase() },
      data: {
        ...dto,
        expiresAt: dto.expiresAt ? new Date(dto.expiresAt) : undefined,
      },
    });
  }
}
